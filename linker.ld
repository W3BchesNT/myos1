OUTPUT_FORMAT("binary")
ENTRY(start)
SECTIONS
{
    . = 0x7C00;
    .text : {
        *(.text)
    }
}
