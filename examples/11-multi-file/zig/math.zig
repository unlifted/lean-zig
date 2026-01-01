// Math utilities module
const std = @import("std");

/// Sum a slice of usizes
pub fn sum(values: []const usize) usize {
    var total: usize = 0;
    for (values) |val| {
        total += val;
    }
    return total;
}

/// Compute average (returns 0 if empty)
pub fn average(values: []const usize) usize {
    if (values.len == 0) return 0;
    return sum(values) / values.len;
}

/// Find maximum value (returns 0 if empty)
pub fn max(values: []const usize) usize {
    if (values.len == 0) return 0;
    var maximum = values[0];
    for (values[1..]) |val| {
        if (val > maximum) maximum = val;
    }
    return maximum;
}
