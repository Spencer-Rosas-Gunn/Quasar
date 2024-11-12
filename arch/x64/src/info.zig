pub const RawPage_t = u39;
pub const page_size = 4096;

pub fn ptrFromPage(t: type, page: RawPage_t) *t {
    return @ptrFromInt(page * page_size);
}
