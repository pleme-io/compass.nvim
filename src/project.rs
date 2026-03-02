use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub name: String,
    pub path: String,
    pub display: String,
    pub score: f64,
    pub open_count: u32,
}

impl Project {
    pub fn new(name: String, path: String, display: String) -> Self {
        Self {
            name,
            path,
            display,
            score: 0.0,
            open_count: 0,
        }
    }
}
