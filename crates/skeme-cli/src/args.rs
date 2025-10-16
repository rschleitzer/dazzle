//! Command-line argument parsing

use clap::Parser;
use std::path::PathBuf;

/// Skeme: A Rust-based code generation tool powered by Scheme templates
#[derive(Parser, Debug)]
#[command(name = "skeme")]
#[command(version, about, long_about = None)]
pub struct Args {
    /// Template file (.scm)
    #[arg(short = 'd', long = "template", required = true)]
    pub template: PathBuf,

    /// Backend selection (xml or text)
    #[arg(short = 't', long = "backend", default_value = "text")]
    pub backend: String,

    /// Template variables (key=value pairs)
    #[arg(short = 'V', long = "var", value_parser = parse_key_val)]
    pub variables: Vec<(String, String)>,

    /// Template search directories
    #[arg(short = 'D', long = "dir")]
    pub search_dirs: Vec<PathBuf>,

    /// Input XML file
    #[arg(required = true)]
    pub input: PathBuf,

    /// Enable verbose output
    #[arg(short, long)]
    pub verbose: bool,
}

/// Parse a single key=value pair
fn parse_key_val(s: &str) -> Result<(String, String), String> {
    let pos = s
        .find('=')
        .ok_or_else(|| format!("invalid KEY=value: no `=` found in `{s}`"))?;
    Ok((s[..pos].to_string(), s[pos + 1..].to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_key_val() {
        let (k, v) = parse_key_val("foo=bar").unwrap();
        assert_eq!(k, "foo");
        assert_eq!(v, "bar");
    }

    #[test]
    fn test_parse_key_val_with_equals_in_value() {
        let (k, v) = parse_key_val("key=val=ue").unwrap();
        assert_eq!(k, "key");
        assert_eq!(v, "val=ue");
    }
}
