%include "x86inc.asm"

%if 2 == SIZE_OF_PIXEL

%include "ip_ssse3_x86-a.inc"

extern pshuffd_zero
extern pshuffw_zero
extern pshuffq_zero
extern pshuffd_w
extern CONVERT_W_TO_DW_CONST_SSSE3

DECLARE_EXTERN_LUMA_COEF_SSSE3 P
DECLARE_EXTERN_CHROMA_COEF_SSSE3 P

%define		X265_OUTPUT_DST_INT					0

%macro SET_DST_INT_ADDRESS 0
%if 1 == X265_OUTPUT_DST_INT
	MOV dst_int, X265_DST_INT_STRIDE
	IMUL dst_int, row
	ADD dst_int, dst_int_parameter
%endif
%endmacro



%macro STORE_DST_INT 3
%if 1 == X265_OUTPUT_DST_INT
%if 8 == COL_SIZE
	STORE_N_BYTES_DATA_ALIGN dst_int   , %1, 16
	STORE_N_BYTES_DATA_ALIGN dst_int+16, %2, 16
	ADD dst_int, 32
%elif 6 == COL_SIZE
	STORE_N_BYTES_DATA_ALIGN dst_int   , %1, 16
	STORE_N_BYTES_DATA_ALIGN dst_int+16, %2, 8
%elif 5 == COL_SIZE
	STORE_N_BYTES_DATA_ALIGN dst_int   , %1, 16
	STORE_N_BYTES_DATA_ALIGN dst_int+16, %2, 4
%elif 4 == COL_SIZE
	STORE_N_BYTES_DATA_ALIGN dst_int   , %1, 16
%elif 2 == COL_SIZE
	STORE_N_BYTES_DATA_ALIGN dst_int, %1, 8
%elif 1 == COL_SIZE
	STORE_N_BYTES_DATA_ALIGN dst_int, %1, 4
%endif
%endif
%endmacro

%macro SET_REF_AND_DST 0
	MOV ref, ref_stride_parameter
	IMUL ref, row
%if X265_LUMA_FLAGS == CHROMA_FLAGS
	SUB ref, 3
%else
	SUB ref, 1
%endif
	ADD ref, ref
	ADD ref, ref_parameter
	MOV dst, dst_stride_parameter
	IMUL dst, row
	ADD dst, dst
	ADD dst, dst_parameter
	SET_DST_INT_ADDRESS
%endmacro

%macro GET_MAX 0
%if P_FLAGS == DST_FLAGS
	MOV SPACE1, 1
	MOV ecx, bit_depth_parameter
	SHL SPACE1, cl
	DEC SPACE1
	MOVD XMAX, SPACE1
	PSHUFB XMAX, [pshuffw_zero]
%endif
%endmacro

%macro GET_OFFSET_AND_SHIFT	0
%if P_FLAGS == DST_FLAGS
	MOV SPACE1, X265_IF_FILTER_PREC_ASM
	MOV r1, SPACE1
	DEC r1
	MOV SPACE2, 1
	SHL SPACE2, cl
	MOVD XOFFSET_AND_SHIFT, SPACE2
	PSHUFB XOFFSET_AND_SHIFT, [pshuffd_zero]
	MOVD XSPACE1, SPACE1
	PSHUFB XSPACE1, [pshuffq_zero]
	MOVLHPS XOFFSET_AND_SHIFT, XSPACE1
%elif S_FLAGS == DST_FLAGS
	MOV SPACE1, X265_IF_FILTER_PREC_ASM
	ADD SPACE1, bit_depth_parameter
	SUB SPACE1, X265_IF_INTERNAL_PREC_ASM
	MOV r1, SPACE1
	MOV SPACE2, X265_IF_INTERNAL_OFFS_ASM
	SHL SPACE2, cl
	MOVD XOFFSET_AND_SHIFT, SPACE2
	PSHUFB XOFFSET_AND_SHIFT, [pshuffd_zero]
	MOVD XSPACE1, SPACE1
	PSHUFB XSPACE1, [pshuffq_zero]
	MOVLHPS XOFFSET_AND_SHIFT, XSPACE1
%endif
%endmacro


%macro PREPARE_PARAMETER 0
	GET_MAX
	GET_OFFSET_AND_SHIFT
%endmacro

%macro READ_N_COL_DATA 3
	READ_N_BYTES_DATA %1, [%2], %3
	ADD %2, %3
%endmacro

%macro STORE_N_COL_DATA 3
%if 8 == COL_SIZE
	STORE_N_BYTES_DATA %1   , %2, 16
	ADD dst, 16
%elif 6 == COL_SIZE
	STORE_N_BYTES_DATA %1   , %2, 12
%elif 5 == COL_SIZE
	STORE_N_BYTES_DATA %1   , %2, 10
%elif 4 == COL_SIZE
	STORE_N_BYTES_DATA %1   , %2,  8
%elif 2 == COL_SIZE
	STORE_N_BYTES_DATA %1   , %2,  4
%elif 1 == COL_SIZE
	STORE_N_BYTES_DATA %1   , %2,  2
%endif
%endmacro

%macro INIT_REF_HEADER_PIXEL 0
	READ_N_COL_DATA XREF1, ref, 16
	READ_N_COL_DATA XREF2, ref, 16
%endmacro

%macro POST_PROCESS_AND_STORE 0
%if P_FLAGS == DST_FLAGS
	MOVQ XSPACE1, XOFFSET_AND_SHIFT
	MOVLHPS XSPACE1, XOFFSET_AND_SHIFT
	PADDD XRESULT1, XSPACE1
%if COL_SIZE > 4
	PADDD XRESULT2, XSPACE1
%endif
	PXOR XSPACE1, XSPACE1
	MOVHLPS XSPACE1, XOFFSET_AND_SHIFT
	PSRAD XRESULT1, XSPACE1
%if COL_SIZE > 4
	PSRAD XRESULT2, XSPACE1
%endif
	PSHUFB XRESULT1, [pshuffd_w]
	PSHUFB XRESULT2, [pshuffd_w]
	PXOR XSPACE1, XSPACE1
	PMAXSW XRESULT1, XSPACE1
%if COL_SIZE > 4
	PMAXSW XRESULT2, XSPACE1
%endif
	PMINSW XRESULT1, XMAX
%if COL_SIZE > 4
	PMINSW XRESULT2, XMAX
%endif
	MOVLHPS XRESULT1, XRESULT2

%else
	MOVQ XSPACE1, XOFFSET_AND_SHIFT
	MOVLHPS XSPACE1, XOFFSET_AND_SHIFT
	PSUBD XRESULT1, XSPACE1
%if COL_SIZE > 4
	PSUBD XRESULT2, XSPACE1
%endif
	PXOR XSPACE1, XSPACE1
	MOVHLPS XSPACE1, XOFFSET_AND_SHIFT
	PSRAD XRESULT1, XSPACE1
%if COL_SIZE > 4
	PSRAD XRESULT2, XSPACE1
%endif
	PSHUFB XRESULT1, [pshuffd_w]
	PSHUFB XRESULT2, [pshuffd_w]
%endif

	MOVLHPS XRESULT1, XRESULT2
	STORE_N_COL_DATA dst, XRESULT1, XRESULT2
%endmacro


%macro X265_IP_FILTER_ONE_ROW_ONE_COL_HOR_P_HELP_SSSE3 1
	%define COL_SIZE %1
%if X265_LUMA_FLAGS == CHROMA_FLAGS
	MOVDQA XRESULT1, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XRESULT1, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XRESULT1, XCOEFF1
	MOVDQA XSPACE1, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE1, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XSPACE1, XCOEFF2
	PADDD XRESULT1, XSPACE1
	MOVLHPS XREF1, XREF2
	PSRLDQ XREF2, 8
	MOVDQA XSPACE1, XREF1
%if COL_SIZE > 4
	MOVDQA XRESULT2, XREF1
%endif
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE1, XREF1
%if COL_SIZE > 4
	PUNPCKLWD XRESULT2, XREF1
%endif
	PSRLDQ XREF1, 2
	PMADDWD XSPACE1, XCOEFF3
%if COL_SIZE > 4
	PMADDWD XRESULT2, XCOEFF1
%endif
	PADDD XRESULT1, XSPACE1
	MOVDQA XSPACE1, XREF1
%if COL_SIZE > 4
	MOVDQA XSPACE2, XREF1
%endif
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE1, XREF1
%if COL_SIZE > 4
	PUNPCKLWD XSPACE2, XREF1
%endif
	PSRLDQ XREF1, 2
	PMADDWD XSPACE1, XCOEFF4
%if COL_SIZE > 4
	PMADDWD XSPACE2, XCOEFF2
%endif
	PADDD XRESULT1, XSPACE1
%if COL_SIZE > 4
	PADDD XRESULT2, XSPACE2
	MOVLHPS XREF1, XREF2
	MOVDQA XREF2, XREF1
	MOVDQA XSPACE2, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE2, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XSPACE2, XCOEFF3
	PADDD XRESULT2, XSPACE2
	MOVDQA XSPACE2, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE2, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XSPACE2, XCOEFF4
	PADDD XRESULT2, XSPACE2
	MOVDQA XREF1, XREF2
%endif
%elif X265_CHROMA_FLAGS == CHROMA_FLAGS
	MOVDQA XRESULT1, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XRESULT1, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XRESULT1, XCOEFF1
	MOVDQA XSPACE1, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE1, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XSPACE1, XCOEFF2
	PADDD XRESULT1, XSPACE1
%if COL_SIZE > 4
	MOVLHPS XREF1, XREF2
	PSRLDQ XREF2, 8
	MOVDQA XRESULT2, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XRESULT2, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XRESULT2, XCOEFF1
	MOVDQA XSPACE1, XREF1
	PSRLDQ XREF1, 2
	PUNPCKLWD XSPACE1, XREF1
	PSRLDQ XREF1, 2
	PMADDWD XSPACE1, XCOEFF2
	PADDD XRESULT2, XSPACE1
	MOVLHPS XREF1, XREF2
	PSRLDQ XREF2, 8
%endif
%endif
	STORE_DST_INT XRESULT1, XRESULT2, XSPACE1
	POST_PROCESS_AND_STORE
%endmacro

%macro X265_IP_FILTER_ONE_ROW_N_COL_HOR_P_HELP_SSSE3 1
	SET_REF_AND_DST
	INIT_REF_HEADER_PIXEL

	MOV col, width_parameter
	CMP col, MAX_COL_SIZE
	JL %%X265_IP_FILTER_ONE_ROW_N_COL_HOR_P_HELP_SSSE3_LABEL_LESS_THAN_MAX_COL_SIZE

%%X265_IP_FILTER_ONE_ROW_N_COL_HOR_P_HELP_SSSE3_LABEL_MAX_COL_SIZE:
	X265_IP_FILTER_ONE_ROW_ONE_COL_HOR_P_HELP_SSSE3 MAX_COL_SIZE
	READ_N_COL_DATA XREF2, ref, 16

	SUB col, MAX_COL_SIZE
	CMP col, MAX_COL_SIZE
	JGE %%X265_IP_FILTER_ONE_ROW_N_COL_HOR_P_HELP_SSSE3_LABEL_MAX_COL_SIZE

%%X265_IP_FILTER_ONE_ROW_N_COL_HOR_P_HELP_SSSE3_LABEL_LESS_THAN_MAX_COL_SIZE:
%if %1 > 0
	X265_IP_FILTER_ONE_ROW_ONE_COL_HOR_P_HELP_SSSE3 %1
%endif
%endmacro

%macro X265_IP_FILTER_N_ROW_N_COL_HOR_P_HELP_SSSE3 1
	MOV row, 0
%%X265_IP_FILTER_N_ROW_N_COL_HOR_P_HELP_SSSE3_LABEL_LOOP:
	X265_IP_FILTER_ONE_ROW_N_COL_HOR_P_HELP_SSSE3 %1
	INC row
	CMP row, height_parameter
	JL %%X265_IP_FILTER_N_ROW_N_COL_HOR_P_HELP_SSSE3_LABEL_LOOP
%endmacro

%macro RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC 1
	MOV r1, 0
	CMP r0, %1
	JNE %%RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC_EXIT
	X265_IP_FILTER_N_ROW_N_COL_HOR_P_HELP_SSSE3 %1
	MOV r1, 1
%%RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC_EXIT:
%endmacro

%macro X265_IP_FILTER_HOR_P_SSSE3_HELP 4
	%define			XCOEFFS						%2
	%define			CHROMA_FLAGS				%3
	%define			DST_FLAGS					%4
	%define			SPACE1						r0
	%define			SPACE2						r2
	%define			SPACE3						r3
	%define			col							r6
	%define			row							r5
	%define			ref							r4
	%define			dst							r3
	%define			ref_stride					r2
	%define			dst_int						r1
	%define			XREF1						XMMR1
	%define			XREF2						XMMR2
	%define			XSPACE1						XMMR0
	%define			XSPACE2						XMMR7
	%define			XRESULT1					XMMR3
	%define			XRESULT2					XMMR4
	%define			XMAX						XMMR5
	%define			XOFFSET_AND_SHIFT			XMMR6
	%define			ref_parameter				r0m
	%define			ref_stride_parameter		r1m
	%define			dst_parameter				r2m
	%define			dst_stride_parameter		r3m
	%define			width_parameter				r4m
	%define			height_parameter			r5m
	%define			bit_depth_parameter			r6m
	%define			dst_int_parameter			r7m
%if X265_LUMA_FLAGS == CHROMA_FLAGS
	%define			XCOEFF1						[XCOEFFS     ]
	%define			XCOEFF2						[XCOEFFS+16*1]
	%define			XCOEFF3						[XCOEFFS+16*2]
	%define			XCOEFF4						[XCOEFFS+16*3]
%elif X265_CHROMA_FLAGS == CHROMA_FLAGS
	%define			XCOEFF1						[XCOEFFS     ]
	%define			XCOEFF2						[XCOEFFS+16*1]
%endif
	%define			MAX_COL_SIZE				8
	%define			MAX_COL_SIZE_BITS			3
cglobal %1, 0, 7

	PREPARE_PARAMETER
	MOV col, width_parameter
	MOV r0, col
	MOV r1, col
	SHR r1, MAX_COL_SIZE_BITS
	SHL r1, MAX_COL_SIZE_BITS
	SUB r0, r1
	RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC  0
	CMP r1, 1
	JE %%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT
	RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC  4
	CMP r1, 1
	JE %%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT
	RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC  1
	CMP r1, 1
	JE %%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT
	RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC  5
	CMP r1, 1
	JE %%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT
	RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC  2
	CMP r1, 1
	JE %%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT
	RUN_AVAILABLE_IP_FILTER_N_ROW_N_COL_HOR_P_FUNC  6
	CMP r1, 1
	JE %%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT
%%X265_IP_FILTER_HOR_P_SSSE3_HELP_EXIT:
	RET
%endmacro

SECTION .text align=16

DEFINE_ALL_IP_FILTER_LUMA_SSSE3_FUNC hor, HOR, p, P, p, P_FLAGS
DEFINE_ALL_IP_FILTER_LUMA_SSSE3_FUNC hor, HOR, p, P, s, S_FLAGS
DEFINE_ALL_IP_FILTER_CHROMA_SSSE3_FUNC hor, HOR, p, P, p, P_FLAGS
DEFINE_ALL_IP_FILTER_CHROMA_SSSE3_FUNC hor, HOR, p, P, s, S_FLAGS

%endif


