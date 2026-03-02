use std::path::Path;
use walkdir::WalkDir;

use crate::project::Project;

pub fn scan_workspaces(roots: &[String], max_depth: u32) -> Vec<Project> {
    let mut projects = Vec::new();

    for root in roots {
        let expanded = expand_tilde(root);
        let root_path = Path::new(&expanded);
        if !root_path.is_dir() {
            continue;
        }

        for entry in WalkDir::new(root_path)
            .max_depth(max_depth as usize)
            .follow_links(true)
            .into_iter()
            .filter_entry(|e| !is_hidden(e))
        {
            let entry = match entry {
                Ok(e) => e,
                Err(_) => continue,
            };

            if !entry.file_type().is_dir() {
                continue;
            }

            let path = entry.path();
            if path.join(".git").is_dir() {
                if let Some(project) = build_project(path, root_path) {
                    projects.push(project);
                }
            }
        }
    }

    projects.sort_by(|a, b| a.display.cmp(&b.display));
    projects.dedup_by(|a, b| a.path == b.path);
    projects
}

fn build_project(path: &Path, root: &Path) -> Option<Project> {
    let name = path.file_name()?.to_str()?.to_string();
    let abs_path = path.to_str()?.to_string();

    let display = path
        .strip_prefix(root)
        .ok()?
        .to_str()?
        .to_string();

    Some(Project::new(name, abs_path, display))
}

fn is_hidden(entry: &walkdir::DirEntry) -> bool {
    entry
        .file_name()
        .to_str()
        .map(|s| s.starts_with('.') && s != ".")
        .unwrap_or(false)
}

fn expand_tilde(path: &str) -> String {
    if let Some(rest) = path.strip_prefix("~/") {
        if let Some(home) = dirs_home() {
            return format!("{}/{}", home, rest);
        }
    }
    path.to_string()
}

fn dirs_home() -> Option<String> {
    directories::BaseDirs::new()
        .map(|d| d.home_dir().to_str().unwrap_or("").to_string())
}
