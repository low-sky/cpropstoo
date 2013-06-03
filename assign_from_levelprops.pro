pro assign_from_levelprops $
   , propfile = propfile $
   , props = props $ 
   , flags = flags $
   , flagfile = flagfile $
   , kernel_ind = kernel_ind $
   , kernfile = kernfile $
   , data = data $
   , infile = infile $
   , mask = mask $
   , inmask = inmask $
   , hdr = hdr $
   , index = index $
   , outfile = outfile $
   , verbose = verbose


; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; READ IN THE DATA
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(infile) gt 0 then begin
     file_data = file_search(infile, count=file_ct)
     if file_ct eq 0 then begin
        message, "Data not found.", /info
        return
     endif else begin
        data = readfits(file_data, hdr)
     endelse
  endif

  if n_elements(mask) eq 0 then begin
     file_mask = file_search(inmask, count=file_ct)
     if file_ct eq 0 then begin
        message, "Mask not found.", /info
        return
     endif else begin
        mask = readfits(file_mask, mask_hdr)
     endelse
  endif


; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; READ IN THE KERNELS
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(kernfile) gt 0 then begin
     if keyword_set(idlformat) then begin
        restore, kernfile
     endif else begin
        readcol, kernfile, comment="#" $
                 , format="L,L,L,F,F,F,F" $
                 , kern_xpix, kern_ypix, kern_zpix $
                 , kern_ra, kern_dec, kern_vel, kern_int
        xyv_to_ind, x=kern_xpix, y=kern_ypix, v=kern_zpix $
                    , sz=size(data), ind=kernel_ind
     endelse
  endif

; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%
; READ IN THE LEVEL PROPERTIES
; &%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%

  if n_elements(propfile) gt 0 then $
    restore, propfile

  if n_elements(flagfile) gt 0 then $
     restore, flagfile ,/v
     

; %&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&
; DEFINITIONS AND DEFAULTS
; %&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&

  cube = data*mask 
  index = [!values.f_nan, !values.f_nan]
  cube_sz = size(cube)
  assign = lonarr(cube_sz[1],cube_sz[2],cube_sz[3])
  next_assgn = 1


; %&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&
; FIND REGIONS 
; %&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&

  ; LOOP OVER KERNELS
  for i = 0L, n_elements(kernel_ind)-1 do begin
  if keyword_set(verbose) then $
     counter, i, n_elements(kernel_ind)-1, 'KERNEL   '    

  ;  GET FLAGS FOR THIS COLUMN
     this_flag = (reform(flag[i,*]))
     this_flag_ind = where(this_flag, bound_ct)
     
     if bound_ct LT 1 then continue 
  
     lowest_flag = min(levels[this_flag_ind])
     lev = where(levels EQ lowest_flag)
     

     
;  GENERATE THE MASK FOR THIS CLOUD
     this_mask = cube gt lowest_flag
     regions = label_region(this_mask, /ulong)
     this_reg = regions eq regions[kernel_ind[i]]
   ;  COPY TO TOTAL MASK
     ind = where(this_reg and regions NE 0 , num_ct)  
  
    if num_ct GT 0 and num_ct EQ props[i,lev].moments.npix.val then $
     if total(assign[ind] GT 0) NE  num_ct then begin  
       assign[ind] = next_assgn 
       index = [[index], [i, lev]]
       next_assgn += 1
     endif  
  endfor

; %&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&
; WRITE OUT FILES
; %&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&%&

  if n_elements(outfile) eq 0 then $
    outfile = 'props_assignment.fits'     
   outfile_b = strmid(outfile,0,strpos(outfile, '.fits'))+'_index.idl' 
  
  out_hdr = hdr
  sxaddpar, hdr, "BUNIT", "ASSIGNMENT"
  writefits, outfile, assign, hdr

  save, index, filename=outfile_b


end