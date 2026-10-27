use std::{fs, thread};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use nix::sys::statvfs::statvfs;

fn sleep_until_next_sec() {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap();
    let sub = now.subsec_nanos();
    if sub != 0 {
        thread::sleep(Duration::new(0, 1_000_000_000 - sub));
    }
}

fn read_cpu() -> (u64, u64) {
    let s = fs::read_to_string("/proc/stat").unwrap();
    let mut parts = s.lines().next().unwrap().split_whitespace();
    parts.next();

    let user:    u64 = parts.next().unwrap_or("0").parse().unwrap();
    let nice:    u64 = parts.next().unwrap_or("0").parse().unwrap();
    let system:  u64 = parts.next().unwrap_or("0").parse().unwrap();
    let idle:    u64 = parts.next().unwrap_or("0").parse().unwrap();
    let iowait:  u64 = parts.next().unwrap_or("0").parse().unwrap();
    let irq:     u64 = parts.next().unwrap_or("0").parse().unwrap();
    let softirq: u64 = parts.next().unwrap_or("0").parse().unwrap();
    let steal:   u64 = parts.next().unwrap_or("0").parse().unwrap();

    let idle_all = idle + iowait;
    let non_idle = user + nice + system + irq + softirq + steal;
    let total = idle_all + non_idle;

    (non_idle, total)
}

fn mem_usage_gib() -> f64 {
    let s = fs::read_to_string("/proc/meminfo").unwrap();
    let mut total_kb = 0.0;
    let mut avail_kb = 0.0;

    for line in s.lines() {
        if line.starts_with("MemTotal:") {
            total_kb = line.split_whitespace().nth(1).unwrap().parse::<f64>().unwrap();
        } else if line.starts_with("MemAvailable:") {
            avail_kb = line.split_whitespace().nth(1).unwrap().parse::<f64>().unwrap();
        }
    }

    let used_kb = total_kb - avail_kb;
    used_kb / (1024.0 * 1024.0)
}

fn disk_usage_gib(path: &str) -> (f64, f64) {
    let vfs = statvfs(path).unwrap();
    let bsize = vfs.block_size() as u64;

    let total = vfs.blocks() * bsize;
    let avail = vfs.blocks_available() * bsize;
    let used = total - avail;

    let gib = 1024.0_f64.powi(3);
    (used as f64 / gib, total as f64 / gib)
}

fn main() {
    sleep_until_next_sec();
    let (mut b_prev, mut t_prev) = read_cpu();

    loop {
        sleep_until_next_sec();

        let (b_now, t_now) = read_cpu();
        let db = b_now.saturating_sub(b_prev) as f64;
        let dt = t_now.saturating_sub(t_prev) as f64;
        b_prev = b_now;
        t_prev = t_now;

        let cpu = if dt == 0.0 { 0.0 } else { (db / dt) * 100.0 };
        let mem_gib = mem_usage_gib();
        let (d_used, d_total) = disk_usage_gib("/");

        println!(
            "{:>5.1}%  \
             {:>4.1} GiB  \
             {:>5.1} GiB / {:>5.1} GiB",
            cpu,
            mem_gib,
            d_used,
            d_total,
        );
    }
}

