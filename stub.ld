OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
EXTERN(_start)
ENTRY(_start)

MEMORY
{
	uart  : ORIGIN = 0x02000058, LENGTH = 168
	ewram : ORIGIN = 0x02000100, LENGTH = 10K
}

__base_addr	=	ORIGIN(ewram);

SECTIONS
{
	.uart :
	{
		KEEP(*(.uart))
		. = ALIGN(4);
	} >uart

	__data_start = . ;

	.crt0 :
	{
		*(.crt0)
		. = ALIGN(4);
	} >ewram

	.text :
	{
		*(.text.*)
		*(.gnu.warning)
		*(.gnu.linkonce.t*)
		*(.glue_7)
		*(.glue_7t)
		. = ALIGN(4);
	} >ewram

	.rodata :
	{
		*(.rodata)
		*all.rodata*(*)
		*(.roda)
		*(.rodata.*)
		*(.gnu.linkonce.r*)
		. = ALIGN(4);
	} >ewram

	.data :
	{
		*(.data)
		*(.data.*)
		*(.gnu.linkonce.d*)
		. = ALIGN(4);
	} >ewram

    __data_end = . ;
	PROVIDE (__data_size = ABSOLUTE(__data_end) - ABSOLUTE(__data_start));

	.bss . (NOLOAD) :
	{
		__bss_start = . ;
		*(.dynbss)
		*(.gnu.linkonce.b*)
		*(.bss*)
		*(.sbss*)
		*(COMMON)
		. = ALIGN(4);
		__bss_end = . ;
	}
}
