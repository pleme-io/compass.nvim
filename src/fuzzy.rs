use nucleo_matcher::pattern::{Atom, AtomKind, CaseMatching, Normalization};
use nucleo_matcher::{Config, Matcher, Utf32Str};

use crate::project::Project;

pub fn fuzzy_filter(query: &str, projects: &[Project]) -> Vec<(usize, u16)> {
    if query.is_empty() {
        return projects.iter().enumerate().map(|(i, _)| (i, 0)).collect();
    }

    let mut matcher = Matcher::new(Config::DEFAULT);
    let atom = Atom::new(
        query,
        CaseMatching::Smart,
        Normalization::Smart,
        AtomKind::Fuzzy,
        false,
    );

    let mut results: Vec<(usize, u16)> = projects
        .iter()
        .enumerate()
        .filter_map(|(idx, project)| {
            let haystack = &project.display;
            let mut buf = Vec::new();
            let haystack_utf32 = Utf32Str::new(haystack, &mut buf);
            atom.score(haystack_utf32, &mut matcher)
                .map(|score| (idx, score))
        })
        .collect();

    results.sort_by(|a, b| b.1.cmp(&a.1));
    results
}
