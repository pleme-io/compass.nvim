use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::project::Project;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrecencyEntry {
    pub path: String,
    pub opens: Vec<DateTime<Utc>>,
    pub total_opens: u32,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct FrecencyStore {
    pub entries: HashMap<String, FrecencyEntry>,
}

impl FrecencyStore {
    pub fn load() -> Self {
        let path = data_file();
        match fs::read_to_string(&path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => Self::default(),
        }
    }

    pub fn save(&self) {
        let path = data_file();
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(json) = serde_json::to_string_pretty(self) {
            let _ = fs::write(&path, json);
        }
    }

    pub fn record_open(&mut self, project_path: &str) {
        let now = Utc::now();
        let entry = self
            .entries
            .entry(project_path.to_string())
            .or_insert_with(|| FrecencyEntry {
                path: project_path.to_string(),
                opens: Vec::new(),
                total_opens: 0,
            });

        entry.opens.push(now);
        entry.total_opens += 1;

        // Keep only the last 100 timestamps to bound storage
        if entry.opens.len() > 100 {
            let drain_count = entry.opens.len() - 100;
            entry.opens.drain(..drain_count);
        }

        self.save();
    }

    pub fn score(&self, project_path: &str) -> f64 {
        let entry = match self.entries.get(project_path) {
            Some(e) => e,
            None => return 0.0,
        };

        let now = Utc::now();
        let mut score = 0.0;

        for open_time in &entry.opens {
            let hours = (now - *open_time).num_hours().max(0) as f64;
            let weight = if hours < 1.0 {
                100.0
            } else if hours < 24.0 {
                80.0
            } else if hours < 168.0 {
                60.0
            } else if hours < 720.0 {
                40.0
            } else {
                20.0
            };
            score += weight;
        }

        score
    }

    pub fn apply_scores(&self, projects: &mut [Project]) {
        for project in projects.iter_mut() {
            project.score = self.score(&project.path);
            if let Some(entry) = self.entries.get(&project.path) {
                project.open_count = entry.total_opens;
            }
        }
    }
}

fn data_file() -> PathBuf {
    directories::ProjectDirs::from("", "", "compass-nvim")
        .map(|dirs| dirs.data_dir().join("frecency.json"))
        .unwrap_or_else(|| PathBuf::from("/tmp/compass-nvim-frecency.json"))
}
