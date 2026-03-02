mod frecency;
mod fuzzy;
mod project;
mod scanner;

use std::cell::RefCell;

use nvim_oxi as oxi;
use oxi::conversion::FromObject;
use oxi::serde::Serializer;
use oxi::{Dictionary, Function, Object};
use serde::Serialize;

use frecency::FrecencyStore;
use project::Project;

struct PluginState {
    projects: Vec<Project>,
    frecency: FrecencyStore,
}

thread_local! {
    static STATE: RefCell<PluginState> = RefCell::new(PluginState {
        projects: Vec::new(),
        frecency: FrecencyStore::load(),
    });
}

fn project_to_dict(p: &Project) -> oxi::Result<Dictionary> {
    let serializer = Serializer::new();
    let obj = p.serialize(serializer).map_err(oxi::Error::from)?;
    Dictionary::from_object(obj).map_err(oxi::Error::from)
}

fn projects_to_dicts(projects: &[Project]) -> Vec<Dictionary> {
    projects
        .iter()
        .filter_map(|p| project_to_dict(p).ok())
        .collect()
}

#[oxi::plugin]
fn compass_core() -> oxi::Result<Dictionary> {
    let scan: Function<(Object, Object), Vec<Dictionary>> = Function::from_fn(
        |args: (Object, Object)| -> Vec<Dictionary> {
            let roots: Vec<String> = match FromObject::from_object(args.0) {
                Ok(r) => r,
                Err(_) => return Vec::new(),
            };
            let max_depth: u32 = match FromObject::from_object(args.1) {
                Ok(d) => d,
                Err(_) => return Vec::new(),
            };

            let mut projects = scanner::scan_workspaces(&roots, max_depth);

            STATE.with(|state| {
                let mut state = state.borrow_mut();
                state.frecency.apply_scores(&mut projects);
                projects.sort_by(|a, b| {
                    b.score
                        .partial_cmp(&a.score)
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
                state.projects = projects.clone();
            });

            projects_to_dicts(&projects)
        },
    );

    let filter: Function<String, Vec<Dictionary>> =
        Function::from_fn(|query: String| -> Vec<Dictionary> {
            STATE.with(|state| {
                let state = state.borrow();
                let matches = fuzzy::fuzzy_filter(&query, &state.projects);
                let filtered: Vec<Project> = matches
                    .iter()
                    .map(|(idx, _)| state.projects[*idx].clone())
                    .collect();
                projects_to_dicts(&filtered)
            })
        });

    let track_open: Function<String, ()> = Function::from_fn(|path: String| {
        STATE.with(|state| {
            let mut state = state.borrow_mut();
            state.frecency.record_open(&path);
        });
    });

    let get_ranked: Function<(), Vec<Dictionary>> =
        Function::from_fn(|_: ()| -> Vec<Dictionary> {
            STATE.with(|state| {
                let state = state.borrow();
                let mut projects = state.projects.clone();
                state.frecency.apply_scores(&mut projects);
                projects.sort_by(|a, b| {
                    b.score
                        .partial_cmp(&a.score)
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
                projects_to_dicts(&projects)
            })
        });

    let api = Dictionary::from_iter([
        ("scan", Object::from(scan)),
        ("filter", Object::from(filter)),
        ("track_open", Object::from(track_open)),
        ("get_ranked", Object::from(get_ranked)),
    ]);

    Ok(api)
}
