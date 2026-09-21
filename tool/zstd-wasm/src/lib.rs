//! zstd の復号だけを持つ、小さな wasm (D-299)。ABI はプラグインと同じ流儀: `alloc` / `dealloc` と、`(ptr << 32) | len` を返す関数。
use std::io::Read;

#[no_mangle]
pub extern "C" fn alloc(len: u32) -> u32 {
    let mut buf = Vec::<u8>::with_capacity(len.max(1) as usize);
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr as u32
}

/// # Safety
/// `ptr` / `len` は [alloc] か [decompress] が返したもの。
#[no_mangle]
pub unsafe extern "C" fn dealloc(ptr: u32, len: u32) {
    drop(Vec::from_raw_parts(ptr as *mut u8, 0, len.max(1) as usize));
}

/// 成功: `(ptr << 32) | len`(呼び出し側が `dealloc(ptr, len)` で返す)。失敗(壊れた入力 / `max_out` 超え): 0。
///
/// # Safety
/// `ptr` / `len` は [alloc] で確保して、入力を書き込んだ領域。
#[no_mangle]
pub unsafe extern "C" fn decompress(ptr: u32, len: u32, max_out: u32) -> u64 {
    let input = std::slice::from_raw_parts(ptr as *const u8, len as usize);
    let Ok(mut dec) = ruzstd::decoding::StreamingDecoder::new(input) else {
        return 0;
    };
    let mut out = Vec::new();
    let mut buf = [0u8; 64 * 1024];
    loop {
        match dec.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => {
                if out.len() + n > max_out as usize {
                    return 0;
                }
                out.extend_from_slice(&buf[..n]);
            }
            Err(_) => return 0,
        }
    }
    if out.is_empty() {
        return 0;
    }
    // dealloc と対になるように、容量 = 長さにそろえる。
    let mut out = out.into_boxed_slice();
    let (p, l) = (out.as_mut_ptr() as u64, out.len() as u64);
    std::mem::forget(out);
    (p << 32) | l
}
