use rustler::{Env, Term};
use std::collections::HashMap;
use typst::foundations::{Array, Datetime, Dict, Str, Value};

use crate::TypstError;

/// Convert a Rustler Term (Elixir data) to a Typst Value
pub fn term_to_value<'a>(term: Term<'a>) -> Result<Value, TypstError> {
    // Try to decode as different types

    // Try boolean first (must come before integer as booleans can be decoded as integers)
    if let Ok(b) = term.decode::<bool>() {
        return Ok(Value::Bool(b));
    }

    // Try integer
    if let Ok(i) = term.decode::<i64>() {
        return Ok(Value::Int(i));
    }

    // Try float
    if let Ok(f) = term.decode::<f64>() {
        return Ok(Value::Float(f));
    }

    // Try string
    if let Ok(s) = term.decode::<String>() {
        return Ok(Value::Str(Str::from(s)));
    }

    // Try list (array)
    if term.is_list() {
        let list: Vec<Term> = term.decode()?;
        let mut array = Array::new();
        for item in list {
            let value = term_to_value(item)?;
            array.push(value);
        }
        return Ok(Value::Array(array));
    }

    // Try map (dictionary or struct)
    if term.is_map() {
        let map: HashMap<String, Term> = term.decode()?;

        // Check if this is an Elixir struct by looking for __struct__ key
        if let Some(struct_term) = map.get("__struct__") {
            if let Ok(struct_name) = struct_term.decode::<String>() {
                // Handle Date, DateTime, and NaiveDateTime structs
                match struct_name.as_str() {
                    "Elixir.Date" => {
                        return convert_date_to_datetime(&map);
                    }
                    "Elixir.DateTime" => {
                        return convert_datetime_to_datetime(&map);
                    }
                    "Elixir.NaiveDateTime" => {
                        return convert_naive_datetime_to_datetime(&map);
                    }
                    _ => {
                        // Unknown struct, treat as regular map but skip __struct__ key
                        let mut dict = Dict::new();
                        for (key, value_term) in map {
                            if key != "__struct__" {
                                let value = term_to_value(value_term)?;
                                dict.insert(Str::from(key), value);
                            }
                        }
                        return Ok(Value::Dict(dict));
                    }
                }
            }
        }

        // Regular map (not a struct)
        let mut dict = Dict::new();
        for (key, value_term) in map {
            let value = term_to_value(value_term)?;
            dict.insert(Str::from(key), value);
        }
        return Ok(Value::Dict(dict));
    }

    // If we get here, we couldn't convert the type
    Err(TypstError::InvalidInput(format!(
        "Unsupported Elixir type for conversion to Typst value"
    )))
}

/// Convert a map of Elixir terms to a Typst Dict
pub fn terms_to_dict<'a>(_env: Env<'a>, term: Term<'a>) -> Result<Dict, TypstError> {
    if !term.is_map() {
        return Err(TypstError::InvalidInput(
            "Expected a map for variables".to_string(),
        ));
    }

    let map: HashMap<String, Term> = term.decode()?;
    let mut dict = Dict::new();

    for (key, value_term) in map {
        let value = term_to_value(value_term)?;
        dict.insert(Str::from(key), value);
    }

    Ok(dict)
}

/// Convert Elixir Date struct to Typst Datetime
fn convert_date_to_datetime(map: &HashMap<String, Term>) -> Result<Value, TypstError> {
    let year = map
        .get("year")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("Date missing year field".to_string()))?;

    let month = map
        .get("month")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("Date missing month field".to_string()))?;

    let day = map
        .get("day")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("Date missing day field".to_string()))?;

    // Create a Typst Datetime with just the date components
    let datetime = Datetime::from_ymd(year as i32, month as u8, day as u8).ok_or_else(|| {
        TypstError::InvalidInput(format!(
            "Invalid date values: year={}, month={}, day={}",
            year, month, day
        ))
    })?;

    Ok(Value::Datetime(datetime))
}

/// Convert Elixir DateTime struct to Typst Datetime
fn convert_datetime_to_datetime(map: &HashMap<String, Term>) -> Result<Value, TypstError> {
    let year = map
        .get("year")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("DateTime missing year field".to_string()))?;

    let month = map
        .get("month")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("DateTime missing month field".to_string()))?;

    let day = map
        .get("day")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("DateTime missing day field".to_string()))?;

    let hour = map
        .get("hour")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("DateTime missing hour field".to_string()))?;

    let minute = map
        .get("minute")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("DateTime missing minute field".to_string()))?;

    let second = map
        .get("second")
        .and_then(|t| t.decode::<i64>().ok())
        .ok_or_else(|| TypstError::InvalidInput("DateTime missing second field".to_string()))?;

    // Create a Typst Datetime with full date and time components
    let datetime = Datetime::from_ymd_hms(
        year as i32,
        month as u8,
        day as u8,
        hour as u8,
        minute as u8,
        second as u8,
    )
    .ok_or_else(|| TypstError::InvalidInput("Invalid datetime values".to_string()))?;

    Ok(Value::Datetime(datetime))
}

/// Convert Elixir NaiveDateTime struct to Typst Datetime
fn convert_naive_datetime_to_datetime(map: &HashMap<String, Term>) -> Result<Value, TypstError> {
    // NaiveDateTime has the same structure as DateTime for our purposes
    convert_datetime_to_datetime(map)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests would require a Rustler environment to run
    // They are here as documentation of expected behavior
}
