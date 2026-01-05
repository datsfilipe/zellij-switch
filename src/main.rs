use lexopt::{prelude::*, Parser};
use std::{collections::BTreeMap, path::PathBuf};
use zellij_tile::prelude::*;

#[derive(Default)]
struct State {
    sessions: Vec<String>,
}

register_plugin!(State);

#[derive(Default)]
struct Args {
    target: Option<String>,
    cwd: Option<PathBuf>,
    layout: Option<String>,
}

fn parse_args(mut parser: Parser) -> Result<Args, lexopt::Error> {
    let mut args = Args::default();

    while let Some(arg) = parser.next()? {
        match arg {
            Long("target") => {
                args.target = Some(parser.value()?.parse()?);
            }
            Long("cwd") | Short('c') => {
                args.cwd = Some(PathBuf::from(parser.value()?));
            }
            Long("layout") | Short('l') => {
                args.layout = Some(parser.value()?.parse()?);
            }
            Value(val) => {
                let s = val.to_string_lossy();
                if s != "session-select" && s != "session-index" && args.target.is_none() {
                    args.target = Some(s.into_owned());
                }
            }
            _ => {}
        }
    }
    Ok(args)
}

impl ZellijPlugin for State {
    fn load(&mut self, _: BTreeMap<String, String>) {
        request_permission(&[
            PermissionType::ChangeApplicationState,
            PermissionType::ReadApplicationState,
        ]);
        subscribe(&[EventType::SessionUpdate]);
    }

    fn update(&mut self, event: Event) -> bool {
        if let Event::SessionUpdate(session_infos, _) = event {
            let active_sessions: Vec<String> =
                session_infos.iter().map(|s| s.name.clone()).collect();

            self.sessions.retain(|s| active_sessions.contains(s));
            for name in active_sessions {
                if !self.sessions.contains(&name) {
                    self.sessions.push(name);
                }
            }
        }
        false
    }

    fn pipe(&mut self, pipe_message: PipeMessage) -> bool {
        let payload = pipe_message.payload.unwrap_or_default();
        let parser = Parser::from_args(shell_words::split(&payload).unwrap_or_default());

        let Ok(args) = parse_args(parser) else {
            return false;
        };
        let Some(target) = args.target else {
            return false;
        };

        let session_name = if let Ok(index) = target.parse::<usize>() {
            self.sessions.get(index).cloned()
        } else {
            Some(target)
        };

        let layout_to_use = match args.layout {
            Some(l) => LayoutInfo::File(format!("{}.kdl", l)),
            None => LayoutInfo::File("default".to_string()),
        };

        if let Some(name) = session_name {
            switch_session_with_layout(Some(&name), layout_to_use, args.cwd);
        }

        false
    }
}
