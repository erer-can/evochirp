.section .bss
input_buf:      .space 1024         # Buffer to store input from user
song_buf:       .space 1024         # Buffer to hold the current state of the song
temp_buf:       .space 1024         # Temporary buffer for intermediate transformations

.section .data
prompt:         .asciz "Enter bird song expression:\n"
newline:        .asciz "\n"
gen:            .asciz "Gen "
debug:          .asciz "You Are Here"
colonsp:        .asciz ": "
numbuf:         .space 3           # Buffer to print generation counter (up to 2 digits)
sparrow:        .asciz "Sparrow "
warbler:        .asciz "Warbler "
nightingale:    .asciz "Nightingale "

.section .text
.global print_gen_song
.type print_gen_song, @function

# ----------------------------------------------------
# print_gen_song:
#   Prints the generation header and current song.
#   Format: Gen X: <song_buf contents>
#   Supports generation numbers in %r13 from 0–999
# ----------------------------------------------------
print_gen_song:
    # Print "Gen "
    mov     $1, %rax
    mov     $1, %rdi
    lea     gen(%rip), %rsi
    mov     $4, %rdx
    syscall

    # Load generation number into EAX
    mov     %r13d, %eax
    cmp     $10, %eax
    jl      .Lpgs_one_digit        # <10 → 1-digit
    cmp     $100, %eax
    jl      .Lpgs_two_digit        # <100 → 2-digit

    # --- Three-digit case (100–999) ---
    mov     %r13d, %eax            # dividend = gen
    xor     %edx, %edx             # clear high half for div
    mov     $100, %ecx
    div     %ecx                   # EAX = gen/100, EDX = gen%100
    add     $'0', %al
    movb    %al, numbuf(%rip)      # hundreds digit

    mov     %edx, %eax             # remainder = gen%100
    xor     %edx, %edx
    mov     $10, %ecx
    div     %ecx                   # EAX = (gen%100)/10, EDX = (gen%100)%10
    add     $'0', %al
    movb    %al, numbuf+1(%rip)    # tens digit
    add     $'0', %dl
    movb    %dl, numbuf+2(%rip)    # ones digit

    # Print three digits
    mov     $1, %rax
    mov     $1, %rdi
    lea     numbuf(%rip), %rsi
    mov     $3, %rdx
    syscall
    jmp     .Lpgs_print_colon

.Lpgs_two_digit:
    # --- Two-digit case (10–99) ---
    xor     %edx, %edx
    mov     $10, %ecx
    div     %ecx                   # EAX = gen/10, EDX = gen%10
    add     $'0', %al
    movb    %al, numbuf(%rip)      # tens digit
    add     $'0', %dl
    movb    %dl, numbuf+1(%rip)    # ones digit

    # Print two digits
    mov     $1, %rax
    mov     $1, %rdi
    lea     numbuf(%rip), %rsi
    mov     $2, %rdx
    syscall
    jmp     .Lpgs_print_colon

.Lpgs_one_digit:
    # --- Single-digit case (0–9) ---
    mov     %r13b, %al
    add     $'0', %al
    movb    %al, numbuf(%rip)

    mov     $1, %rax
    mov     $1, %rdi
    lea     numbuf(%rip), %rsi
    mov     $1, %rdx
    syscall

.Lpgs_print_colon:
    # Print ": "
    mov     $1, %rax
    mov     $1, %rdi
    lea     colonsp(%rip), %rsi
    mov     $2, %rdx
    syscall

    # Print current song buffer (up to 1024 bytes)
    mov     $1, %rax
    mov     $1, %rdi
    lea     song_buf(%rip), %rsi
    mov     $1024, %rdx
    syscall

    # Print newline
    mov     $1, %rax
    mov     $1, %rdi
    lea     newline(%rip), %rsi
    mov     $1, %rdx
    syscall

    ret
# ----------------------------------------------------
# _start:
#   Entry point of the program.
#   - Prints the prompt
#   - Reads the input into input_buf
#   - Dispatches to correct species handler
# ----------------------------------------------------
.global _start
_start:
    # Print user prompt
    mov     $1, %rax
    mov     $1, %rdi
    lea     prompt(%rip), %rsi
    mov     $28, %rdx
    # syscall is commented 

    # Read input into input_buf
    mov     $0, %rax
    mov     $0, %rdi
    lea     input_buf(%rip), %rsi
    mov     $1024, %rdx
    syscall

    # Initialize generation count: starts at -1 (will be incremented at start of each gen)
    xor     %r13, %r13
    add     $-1, %r13

    # Initialize note count or general-purpose counter
    xor     %r14, %r14

    # Species dispatch: look at first char in input
    mov     (%rsi), %al
    cmp     $'S', %al
    je      .case_sparrow

    mov     (%rsi), %al
    cmp     $'W', %al
    je      .case_warbler

    mov     (%rsi), %al
    cmp     $'N', %al
    je      .case_nightingale

    # If species not recognized, exit
    jmp     .exit


# ------------------------------------------------------------
# Sparrow-specific Execution Block
# Initializes pointer to input buffer after species name
# and starts processing tokens one by one.
# ------------------------------------------------------------
.case_sparrow:
    mov     %rsi, %r12              # r12 ← pointer to input_buf
    add     $8, %r12                # skip "Sparrow" (assumed 8 chars)
    lea     temp_buf(%rip), %r15    # r15 ← write pointer to temp_buf
    jmp     .sparrow_loop


# ------------------------------------------------------------
# .sparrow_loop:
# Main interpreter loop for Sparrow species.
# Handles notes and dispatches operators.
# ------------------------------------------------------------
.sparrow_loop:
    mov     (%r12), %cl             # load next character/token

    # Operator dispatching
    cmp     $'+', %cl
    je      .sparrow_merge
    cmp     $'*', %cl
    je      .sparrow_repeat
    cmp     $'-', %cl
    je      .sparrow_reduce
    cmp     $'H', %cl
    je      .sparrow_harm

    # Otherwise: treat as a note, write to temp_buf
    mov     %cl, (%r15)             # write note
    add     $1, %r12
    add     $1, %r15

    movb    $0x20, (%r15)           # write a space character
    add     $1, %r15

    # Check for end of input (null-terminator)
    mov     (%r12), %cl
    cmp     $0, %cl
    je      .exit

    add     $1, %r12                # move to next char

    # Update applicable note count in %r14 (max 2)
    cmp     $2, %r14
    jne     .do_inc
    jmp     .skip_inc

.do_inc:
    inc     %r14

.skip_inc:
    jmp     .sparrow_loop


# ------------------------------------------------------------
# .sparrow_loop_end:
# Prints "Sparrow Gen X: ..." using syscall and macro.
# Then jumps back to continue processing.
# ------------------------------------------------------------
.sparrow_loop_end:
    mov     $1, %rax
    mov     $1, %rdi
    lea     sparrow(%rip), %rsi     # species name
    mov     $8, %rdx
    syscall

    call    print_gen_song          # print generation header + song
    jmp     .sparrow_loop


# ------------------------------------------------------------
# .sparrow_merge:
# Implements '+' operator for Sparrow:
#     X Y + → X-Y (merge most recent 2 notes)
# Requires at least 2 recent notes.
# ------------------------------------------------------------
.sparrow_merge:
    cmp     $2, %r14
    jne     .sparrow_merge_skip     # Not enough notes → skip

.sparrow_do_merge:
    movb    $'-', -3(%r15)          # overwrite space before Y with '-'

.sparrow_merge_skip:
    add     $2, %r12                # skip operator and space
    add     $2, %r15                # adjust temp_buf write pointer
    inc     %r13                    # increment generation counter

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx
    xor     %r14, %r14              # reset note count

copy_loop:
    movb    (%r10), %al
    movb    %al, (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     copy_loop

    jmp     .sparrow_loop_end       # print and continue


# ------------------------------------------------------------
# .sparrow_reduce:
# Implements '-' operator for Sparrow:
# Removes the first occurrence of the softest note
# using priority: C > T > D
# ------------------------------------------------------------
.sparrow_reduce:
    # Start by scanning for 'C'
    lea     temp_buf(%rip), %r10

.sr_find_C:
    movb    (%r10), %al
    cmpb    $0, %al
    je      .sr_try_T           # End of buffer, try next priority
    cmpb    $'C', %al
    jne     .sr_next_C
    jmp     .sr_remove          # Found 'C', remove it

.sr_next_C:
    inc     %r10
    jmp     .sr_find_C

# Try to find 'T' if 'C' not found
.sr_try_T:
    lea     temp_buf(%rip), %r10

.sr_find_T:
    movb    (%r10), %al
    cmpb    $0, %al
    je      .sr_try_D           # End of buffer, try 'D'
    cmpb    $'T', %al
    jne     .sr_next_T
    jmp     .sr_remove          # Found 'T', remove it

.sr_next_T:
    inc     %r10
    jmp     .sr_find_T

# Try to find 'D' if 'T' not found
.sr_try_D:
    lea     temp_buf(%rip), %r10

.sr_find_D:
    movb    (%r10), %al
    cmpb    $0, %al
    je      .sr_not_found       # End of buffer, nothing found
    cmpb    $'D', %al
    jne     .sr_next_D
    jmp     .sr_remove          # Found 'D', remove it

.sr_next_D:
    inc     %r10
    jmp     .sr_find_D

# If no removable note found, just skip input and print
.sr_not_found:
    add     $2, %r12            # Skip "- " in input stream
    inc     %r13                # Generation++
    jmp     .sr_copy_print


# ------------------------------------------------------------
# .sr_remove:
# Removes the selected note + its trailing space
# (%r10 points to note), shifts remaining buffer left
# ------------------------------------------------------------
.sr_remove:
    lea     2(%r10), %rsi       # rsi ← address of next note after this one
    add     $-2, %r15           # move write pointer back by 2 (note + space)

.sr_shift:
    movb    (%rsi), %al
    movb    %al,    (%r10)
    inc     %r10
    inc     %rsi
    cmpb    $0, %al             # continue until null-terminator
    jne     .sr_shift

    add     $2, %r12            # Skip "- " in input stream
    inc     %r13                # Generation++

    # Fall through to copy-and-print stage

.sr_copy_print:
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

    # Decide note count heuristic (%r14) based on final %r15
    cmp     %r10, %r15
    jl      .r15_less_r10
    je      .r15_eq_r10

    mov     $2, %r14
    jmp     .cmp_done

.r15_less_r10:
    mov     $0, %r14
    jmp     .cmp_done

.r15_eq_r10:
    mov     $1, %r14

.cmp_done:
    # Proceed to actual copying loop

.copy_SReduce_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_SReduce_loop

    jmp     .sparrow_loop_end


# ------------------------------------------------------------
# .sparrow_repeat:
# Implements '*' operator for Sparrow:
#   → repeats the most recent note (X → X X)
# Requires at least 1 applicable note.
# ------------------------------------------------------------
.sparrow_repeat:
    cmp     $1, %r14
    jl      .sparrow_repeat_skip      # Skip if not enough notes

.sparrow_do_repeat:
    movb    $' ', 1(%r15)             # place a space after the new note
    movb    -2(%r15), %bl             # copy the most recent note (before the last space)
    movb    %bl, (%r15)               # place it at the current position
    inc     %r15
    inc     %r15

    # Update note count if still under 2
    cmp     $2, %r14
    jne     .do_inc_2
    jmp     .skip_inc_2

.do_inc_2:
    inc     %r14

.skip_inc_2:

.sparrow_repeat_skip:
    add     $2, %r12                  # Skip "* " from input
    inc     %r13                      # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

.copy_SR_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_SR_loop

    jmp     .sparrow_loop_end


# ------------------------------------------------------------
# .sparrow_harm:
# Implements 'H' operator for Sparrow:
# Applies global transformation:
#   C → T
#   T → C
#   D → D-T
# ------------------------------------------------------------
.sparrow_harm:
    add     $2, %r12                  # Skip "H " in input
    inc     %r13                      # Generation++

    # Setup: r10 = src (temp_buf), r11 = dst (song_buf)
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11

.harm_loop:
    movb    (%r10), %al
    cmpb    $0, %al
    je      .harm_done               # End of buffer

    cmpb    $'C', %al
    je      .harm_C
    cmpb    $'T', %al
    je      .harm_T
    cmpb    $'D', %al
    je      .harm_D

    # Copy other characters as-is (e.g., spaces)
    movb    %al, (%r11)
    inc     %r11
    inc     %r10
    jmp     .harm_loop

.harm_C:
    movb    $'T', (%r11)
    inc     %r11
    inc     %r10
    jmp     .harm_loop

.harm_T:
    movb    $'C', (%r11)
    inc     %r11
    inc     %r10
    jmp     .harm_loop

.harm_D:
    # Replace D␣ with "D-T␣"
    movb    $'D', (%r11)
    inc     %r11
    movb    $'-', (%r11)
    inc     %r11
    movb    $'T', (%r11)
    inc     %r11
    movb    $' ', (%r11)
    inc     %r11

    add     $2, %r10                 # Skip original "D␣"
    jmp     .harm_loop

.harm_done:
    # Null-terminate song_buf
    movb    $0, (%r11)

    # Copy harmonized song_buf back into temp_buf
    lea     song_buf(%rip), %r10
    lea     temp_buf(%rip), %r11

.copy_back:
    movb    (%r10), %al
    movb    %al, (%r11)
    inc     %r10
    inc     %r11
    cmpb    $0, (%r10)
    jne     .copy_back

    # Find new end of temp_buf, store in r15
    lea     temp_buf(%rip), %r15

.find_end:
    movb    (%r15), %al
    cmpb    $0, %al
    je      .print_harm
    inc     %r15
    jmp     .find_end

.print_harm:
    jmp     .sparrow_loop_end        # Print harmonized song


# ------------------------------------------------------------
# .case_warbler:
# Entry point for Warbler evolution
# Sets up pointers and enters the operator dispatch loop
# ------------------------------------------------------------
.case_warbler:
    mov     %rsi, %r12                # r12 ← start of input
    add     $8, %r12                  # skip "Warbler " (8 bytes)
    lea     temp_buf(%rip), %r15     # r15 ← write pointer into temp_buf
    jmp     .warbler_loop


# ------------------------------------------------------------
# .warbler_loop:
# Main loop for token-by-token evaluation
# Dispatches to operator logic or adds note to temp_buf
# ------------------------------------------------------------
.warbler_loop:
    mov     (%r12), %cl

    # Operator dispatch
    cmp     $'+', %cl
    je      .warbler_merge
    cmp     $'*', %cl
    je      .warbler_repeat
    cmp     $'-', %cl
    je      .warbler_reduce
    cmp     $'H', %cl
    je      .warbler_harm

    # Treat as note — store to temp_buf
    mov     %cl, (%r15)
    add     $1, %r12
    add     $1, %r15

    movb    $0x20, (%r15)            # write a space after the note
    add     $1, %r15

    # End of input check
    mov     (%r12), %cl
    cmp     $0, %cl
    je      .exit
    add     $1, %r12

    # Note count management: track most recent 2 notes
    cmp     $2, %r14
    jne     .do_inc_W
    jmp     .skip_inc_W

.do_inc_W:
    inc     %r14

.skip_inc_W:
    jmp     .warbler_loop


# ------------------------------------------------------------
# .warbler_loop_end:
# Finalization and printing for a generation
# ------------------------------------------------------------
.warbler_loop_end:
    mov     $1, %rax
    mov     $1, %rdi
    lea     warbler(%rip), %rsi      # print species name
    mov     $8, %rdx
    syscall

    call    print_gen_song           # print "Gen X: ..." and song
    jmp     .warbler_loop            # continue evaluation


# ------------------------------------------------------------
# .warbler_merge:
# Implements '+' operator for Warbler:
#   → transforms last two notes into "T-C␣"
# Requires r14 ≥ 2
# ------------------------------------------------------------
.warbler_merge:
    cmp     $2, %r14
    jl      .wm_skip                 # if not enough notes, skip op

.wm_do_merge:
    sub     $4, %r15                 # remove two notes + spaces

    # Write new transformed note sequence "T-C␣"
    movb    $'T', (%r15)
    inc     %r15
    movb    $'-', (%r15)
    inc     %r15
    movb    $'C', (%r15)
    inc     %r15
    movb    $' ', (%r15)
    inc     %r15

.wm_skip:
    add     $2, %r12                 # skip "+␣" in input
    inc     %r13                     # generation++

    # Copy updated temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx
    xor     %r14, %r14               # reset note count

.copy_WM_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_WM_loop

    jmp     .warbler_loop_end


# ------------------------------------------------------------
# .warbler_reduce:
# Implements '-' operator for Warbler:
#   → removes the last note (by backing up 2 bytes)
# Only applies if at least one note is present
# ------------------------------------------------------------
.warbler_reduce:
    lea     temp_buf(%rip), %r10
    cmp     %r10, %r15
    je      .wrd_skip              # No notes to reduce → skip

.wrd_do_reduce:
    sub     $2, %r15               # Back up over "<note><space>"
    movb    $' ', (%r15)           # Replace with space (ensures formatting)

.wrd_skip:
    add     $2, %r12               # Skip "- " in input
    inc     %r13                   # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

.copy_WRep_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_WRep_loop

    jmp     .warbler_loop_end


# ------------------------------------------------------------
# .warbler_repeat:
# Implements '*' operator for Warbler:
#   → echoes the last two notes (X Y → X Y X Y)
# Only applies if at least 2 notes are present
# ------------------------------------------------------------
.warbler_repeat:
    cmp     $2, %r14
    jl      .wr_skip               # Not enough notes → skip

.wr_do_repeat:
    lea     -4(%r15), %r10         # Point to last two-pair block
    mov     $4, %rcx               # Repeat 4 bytes: [note][space][note][space]

.copy_WR:
    movb    (%r10), %al
    movb    %al,    (%r15)
    inc     %r10
    inc     %r15
    dec     %rcx
    jne     .copy_WR

.wr_skip:
    add     $2, %r12               # Skip "* " in input
    inc     %r13                   # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

.copy_WR_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_WR_loop

    jmp     .warbler_loop_end


# ------------------------------------------------------------
# .warbler_harm:
# Implements 'H' operator for Warbler:
#   → appends a trill ("T␣") to the end of the current sequence
# Only applies if there's at least one note in temp_buf
# ------------------------------------------------------------
.warbler_harm:
    lea     temp_buf(%rip), %r10
    cmp     %r10, %r15
    je      .wh_skip               # No notes → skip

.wh_do_harm:
    movb    $'T', (%r15)           # Append 'T'
    inc     %r15
    movb    $' ', (%r15)           # Followed by space
    inc     %r15

.wh_skip:
    add     $2, %r12               # Skip "H " in input
    inc     %r13                   # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

.copy_WH_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_WH_loop

    jmp     .warbler_loop_end


# ------------------------------------------------------------
# .case_nightingale:
# Entry for Nightingale species evolution
# Prepares pointers and enters operator dispatch loop
# ------------------------------------------------------------
.case_nightingale:
    mov     %rsi, %r12                 # r12 ← start of input
    add     $12, %r12                  # skip "Nightingale " (12 bytes)
    lea     temp_buf(%rip), %r15       # r15 ← write ptr for temp_buf
    jmp     .nightingale_loop


# ------------------------------------------------------------
# .nightingale_loop:
# Main input-processing loop
# Handles operators and appends notes into temp_buf
# ------------------------------------------------------------
.nightingale_loop:
    mov     (%r12), %cl

    # Operator dispatch
    cmp     $'+', %cl
    je      .nightingale_merge
    cmp     $'*', %cl
    je      .nightingale_repeat
    cmp     $'-', %cl
    je      .nightingale_reduce
    cmp     $'H', %cl
    je      .nightingale_harm

    # Append note into temp_buf
    mov     %cl, (%r15)
    add     $1, %r12
    add     $1, %r15

    movb    $0x20, (%r15)             # append space
    add     $1, %r15

    # Check for end of input
    mov     (%r12), %cl
    cmp     $0, %cl
    je      .exit
    add     $1, %r12

    # Manage recent-note count (max 2 for merges)
    cmp     $2, %r14
    jne     .do_inc_N
    jmp     .skip_inc_N

.do_inc_N:
    inc     %r14

.skip_inc_N:
    jmp     .nightingale_loop


# ------------------------------------------------------------
# .nightingale_loop_end:
# Prints "Nightingale Gen X: ..." with current song
# ------------------------------------------------------------
.nightingale_loop_end:
    mov     $1, %rax
    mov     $1, %rdi
    lea     nightingale(%rip), %rsi   # print species name
    mov     $12, %rdx
    syscall

    call    print_gen_song            # call macro to print generation
    jmp     .nightingale_loop         # resume parsing


# ------------------------------------------------------------
# .nightingale_merge:
# Implements '+' operator for Nightingale:
#   → duplicates last two notes: X Y → X Y X Y
# Only executes if at least two notes present
# ------------------------------------------------------------
.nightingale_merge:
    cmp     $2, %r14
    jne     .nightingale_merge_skip   # not enough notes → skip

.nightingale_do_merge:
    # Duplicate the last 4 bytes (note1 space note2 space)
    # r15 points just after the last space
    # Copy from r15 - 4 to r15

    movb    -4(%r15), %al             # X
    movb    %al,     (%r15)
    movb    -3(%r15), %al             # space
    movb    %al,     1(%r15)
    movb    -2(%r15), %al             # Y
    movb    %al,     2(%r15)
    movb    -1(%r15), %al             # space
    movb    %al,     3(%r15)
    add     $4, %r15                  # advance write pointer

.nightingale_merge_skip:
    add     $2, %r12                  # Skip "+ " in input
    inc     %r13                      # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

.copy_loop_NM:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_loop_NM

    jmp     .nightingale_loop_end


# ------------------------------------------------------------
# .nightingale_repeat:
# Implements '*' operator for Nightingale:
#   → duplicates the entire current song
# Done via rep movsb on [temp_buf] to append it after itself
# ------------------------------------------------------------
.nightingale_repeat:
    # Optional guard: if r14 < 0, skip
    cmp     $0, %r14
    jl      .nightingale_repeat_skip

.nightingale_do_repeat:
    # r15 = end of song in temp_buf
    # Compute length = r15 - temp_buf
    lea     temp_buf(%rip), %rsi      # rsi ← base address of temp_buf
    mov     %r15, %rdi                # rdi ← end of data
    sub     %rsi, %rdi                # rdi ← data length (in bytes)

    # rdi now holds the byte count
    # Prepare rep movsb to duplicate the song in-place
    mov     %rdi, %rcx                # rcx ← count of bytes to move
    lea     temp_buf(%rip), %rsi      # rsi ← source: start of temp_buf
    lea     temp_buf(%rip), %rdi
    add     %rcx, %rdi                # rdi ← destination: after original data

    rep movsb                         # copy [rsi, rsi+rcx) → [rdi, rdi+rcx)

    mov     %rdi, %r15                # update r15 to point past duplicated data

.nightingale_repeat_skip:
    add     $2, %r12                  # Skip "* " in input
    inc     %r13                      # Generation++

    # Copy updated temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

.copy_Nrep_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_Nrep_loop

    jmp     .nightingale_loop_end

# ------------------------------------------------------------
# .nightingale_reduce:
# Implements '-' operator for Nightingale:
#   → removes the last note if it repeats (X X → X)
# ------------------------------------------------------------
.nightingale_reduce:
    cmp     $2, %r14
    jl      .nightingale_reduce_skip     # Not enough notes → skip

.nightingale_do_reduce:
    mov     %r15, %r11
    lea     -2(%r11), %r11               # r11 → last note
    movb    (%r11), %al                  # AL = last note
    movb    -2(%r11), %bl                # BL = penultimate note
    cmpb    %bl, %al
    jne     .nightingale_reduce_skip     # Only reduce if equal

    sub     $2, %r15                     # Remove note+space
    movb    $' ', (%r11)                 # Blank out leftover space

.nightingale_reduce_skip:
    add     $2, %r12                     # Skip "- " in input
    inc     %r13                         # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx

    # Adjust %r14 depending on buffer size
    cmp     %r10, %r15
    jl      .r15_less_r10_2
    je      .r15_eq_r10_2
    mov     $2, %r14
    jmp     .cmp_done_2

.r15_less_r10_2:
    mov     $0, %r14
    jmp     .cmp_done_2

.r15_eq_r10_2:
    mov     $1, %r14

.cmp_done_2:

.copy_NR_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_NR_loop

    jmp     .nightingale_loop_end


# ------------------------------------------------------------
# .nightingale_harm:
# Implements 'H' operator for Nightingale:
#   → Rearranges last three notes:
#     X Y Z → X-Z Y-X
# ------------------------------------------------------------
.nightingale_harm:
    # Compute buffer size = r15 - temp_buf
    lea     temp_buf(%rip), %r10
    mov     %r15, %r11
    sub     %r10, %r11                   # r11 = total bytes written

    cmp     $6, %r11                     # 3 notes * 2 bytes each
    jl      .nh_skip                     # Too short → skip

.nh_do_harm:
    # Load last 3 notes from temp_buf
    mov     %r15, %r10

    lea     -6(%r10), %r11              # r11 → X
    movb    (%r11), %al                 # AL = X

    lea     -4(%r10), %r11              # r11 → Y
    movb    (%r11), %bl                 # BL = Y

    lea     -2(%r10), %r11              # r11 → Z
    movb    (%r11), %cl                 # CL = Z

    # Remove the original 3 pairs (6 bytes)
    sub     $6, %r15

    # Write "X-Z "
    movb    %al, (%r15)
    inc     %r15
    movb    $'-', (%r15)
    inc     %r15
    movb    %cl, (%r15)
    inc     %r15
    movb    $' ', (%r15)
    inc     %r15

    # Write "Y-X "
    movb    %bl, (%r15)
    inc     %r15
    movb    $'-', (%r15)
    inc     %r15
    movb    %al, (%r15)
    inc     %r15
    movb    $' ', (%r15)
    inc     %r15

.nh_skip:
    add     $2, %r12                     # Skip "H " in input
    inc     %r13                         # Generation++

    # Copy temp_buf → song_buf
    lea     temp_buf(%rip), %r10
    lea     song_buf(%rip), %r11
    mov     $1024, %rcx
    xor     %r14, %r14                   # Reset note counter

.copy_NH_loop:
    movb    (%r10), %al
    movb    %al,    (%r11)
    inc     %r10
    inc     %r11
    dec     %rcx
    jne     .copy_NH_loop

    jmp     .nightingale_loop_end


##################################
# Exit syscall
##################################
.exit:
    mov $60, %rax
    xor %rdi, %rdi
    syscall
