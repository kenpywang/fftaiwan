* Preamble  --------------------------------------------------------------------

foreach obj in mata matrix programs frames {
	clear `obj'
}
set more off
pwd

local tej_stock_dsf "" // Put the path of daily stock data in a CSV file here. 
local tej_stock_dse "" // Put the path of daily market index data in a CSV file here.
local tej_macro_drf "" // Put the path of daily risk-free rates in a CSV file here. 

capture program drop genport
program define genport

	version 16.0
	syntax, Standard(string)
	
	keep 年月日 *_`standard'
	drop if missing(sv_`standard')
	duplicates drop
	rename *_`standard' *
	reshape wide vwret, i(年月日) j(sv)
	isid 年月日
	*tostring 年月日, generate(年月日str)
	*generate date = date(年月日str, "YMD"), before(年月日)
	*format %td date
	*tsset date
	foreach v of varlist vwret* {
		quietly count if missing(`v')
		if r(N)>0 {
			display as result "WARNING from genfact.do: `v' of the `standard' version has missing values."
		}
	}

end

capture program drop gensmb
program define gensmb

	version 16.0
	
	forvalues s = 1/2 {
		egen vwret`s' = rowmean(vwret`s'*)
	}
	generate smb = vwret1 - vwret2
	forvalues s = 1/2 {
		drop vwret`s'
	}

end

capture program drop genhml
program define genhml

	version 16.0
	
	foreach v of numlist 1 3 {
		egen vwret`v' = rowmean(vwret*`v')
	}
	generate hml = vwret3 - vwret1
	foreach v of numlist 1 3 {
		drop vwret`v'
	}

end

* Main ---------------------------------------------------------------------------

* Daily Factors

** Get a simplified version of the stock data

import delimited "`tej_stock_dsf'", varnames(1) case(preserve) encoding("Big5") clear stringcols(1)
keep 證券代碼 簡稱 年月日 報酬率 市值百萬元 市場別
isid 證券代碼 年月日
generate 年 = floor(年月日/10000)
tostring 年月日, generate(年月日str)
generate mdate = mofd(date(年月日str, "YMD"))
format %tm mdate
quietly count if missing(mdate)
if r(N)>0 {
	display as error "ERROR from genfact.do: Some mdates are missing."
	exit
}
merge m:1 證券代碼 年 using "./data/bm12.dta", keep(match master) keepusing(YL1淨值市價比12) nogenerate
merge m:1 證券代碼 年 using "./data/bm5.dta", keep(match master) keepusing(淨值市價比5) nogenerate
preserve
keep 證券代碼 年-淨值市價比5
duplicates drop
egen id = group(證券代碼)
xtset id mdate
generate ML6YL1淨值市價比12 = L6.YL1淨值市價比12
generate ML5淨值市價比5 = L5.淨值市價比5
keep 證券代碼 mdate ML*
xtset, clear
tempfile MLbm
save `MLbm', replace
restore
merge m:1 證券代碼 mdate using `MLbm', keep(match master) 
quietly count if _merge!=3 
if r(N)>0 {
	display as error "ERROR from genfact.do: Some observations cannot be matched."
	exit
}
else drop _merge
save "./data/stock.dta", replace

** Get the market factor

import delimited "`tej_macro_drf'", varname(1) case(preserve) encoding("Big5") stringcols(1) clear
keep if 證券代碼=="5844"
isid 年月日
keep 年月日 一年定存
rename 一年定存 一銀一年定存
tostring 年月日, generate(年月日str)
generate date = date(年月日str, "YMD")
format %td date
tsset date
tsfill
replace 年月日 = year(date)*10000 + month(date)*100 + day(date) if missing(年月日)
sort date
replace 一銀一年定存 = 一銀一年定存[_n-1] if missing(一銀一年定存)
keep 年月日 一銀一年定存
isid 年月日
tsset, clear
replace 一銀一年定存 = 一銀一年定存/365
tempfile rf
save `rf', replace

import delimited "`tej_stock_dse'", varname(1) case(preserve) encoding("Big5") clear
isid 年月日
keep 年月日 報酬率
rename 報酬率 大盤報酬率
merge 1:1 年月日 using `rf', keep(match master) nogenerate
generate mkt = 大盤報酬率 - 一銀一年定存
keep 年月日 mkt
save "./data/mkt.dta", replace

** Get the SMB and HML factors

use "./data/mebp.dta", clear
foreach month of numlist 6 5 {
	preserve
	keep if mod(年月, 100)==`month'
	generate 年 = floor(年月/100), before(年月)
	isid 年
	drop 年月
	keep 年 p50
	rename p50 me`month'p50
	tempfile me`month'p
	save `me`month'p', replace
	restore
}

foreach month of numlist 12 5 {
	use "./data/bm`month'bp.dta", clear
	keep 年 p30 p70
	tsset 年
	rename p* bm`month'p*
	if `month'==12 {
		foreach p of numlist 30 70 {
			generate YL1bm`month'p`p' = L1.bm`month'p`p'
		}
	}
	tsset, clear
	tempfile bm`month'p
	save `bm`month'p', replace
}

use "./data/stock.dta", clear
foreach f in me bm {
	if "`f'"=="me" local mlist "6 5"
	else local mlist "12 5"
	foreach month of numlist `mlist' {
		merge m:1 年 using ``f'`month'p', keep(match master) nogenerate
	}
}
preserve
keep 年 mdate me6p50 me5p50 bm12p30 bm12p70 YL1bm12p30 YL1bm12p70 bm5p30 bm5p70
duplicates drop
tsset mdate
foreach month of numlist 6 5 {
	generate ML`month'me`month'p50 = L`month'.me`month'p50
}
foreach p of numlist 30 70 {
	generate ML6YL1bm12p`p' = L6.YL1bm12p`p'
	generate ML5bm5p`p' = L5.bm5p`p'
}
keep mdate ML*
isid mdate
tsset, clear
tempfile MLmebmbp
save `MLmebmbp', replace
restore
merge m:1 mdate using `MLmebmbp', keep(match master) 
quietly count if _merge!=3 
if r(N)>0 {
	display as error "ERROR from genfact.do: Some observations cannot be matched."
	exit
}
else drop _merge
drop YL* me* bm12p* bm5p* 淨值市價比5
rename (ML6me6p50 ML6YL1bm12p30 ML6YL1bm12p70 ML6YL1淨值市價比12) (me50_ff bm30_ff bm70_ff bm_ff)
rename (ML5me5p50 ML5bm5p30 ML5bm5p70 ML5淨值市價比5) (me50_tej bm30_tej bm70_tej bm_tej)
foreach month of numlist 6 5 {
	bysort 證券代碼 年 mdate (年月日): generate 市值百萬元`month' = 市值百萬元 if _n==_N & month(dofm(mdate))==`month'
	bysort 證券代碼 年: fillmissing 市值百萬元`month'
}
preserve
keep 證券代碼 年 市值百萬元6 市值百萬元5
duplicates drop
isid 證券代碼 年
restore
preserve
keep 證券代碼 年 mdate 市值百萬元6 市值百萬元5
duplicates drop
egen id = group(證券代碼)
tsset id mdate
generate 市值百萬元_ff = L6.市值百萬元6
generate 市值百萬元_tej = L5.市值百萬元5
drop id
tsset, clear
tempfile 市值百萬元
save `市值百萬元', replace
restore
merge m:1 證券代碼 mdate using `市值百萬元', keepusing(*_ff *_tej) 
quietly count if _merge!=3
if r(N)>0 {
	display as error "ERROR from genfact.do: Some observations cannot be matched."
	exit
}
else drop _merge

preserve
keep 證券代碼 年 mdate *_ff *_tej
duplicates drop
isid 證券代碼 mdate
foreach standard in ff tej {
	generate size_`standard' = .
	replace size_`standard' = 1 if 市值百萬元_`standard' <= me50_`standard' & !missing(市值百萬元_`standard', me50_`standard')
	replace size_`standard' = 2 if 市值百萬元_`standard' > me50_`standard' & !missing(市值百萬元_`standard', me50_`standard')
	
	generate value_`standard' = .
	replace value_`standard' = 1 if bm_`standard' <= bm30_`standard' & !missing(bm_`standard', bm30_`standard')
	replace value_`standard' = 2 if bm_`standard' > bm30_`standard' & bm_`standard' <= bm70_`standard' & !missing(bm_`standard', bm30_`standard', bm70_`standard')
	replace value_`standard' = 3 if bm_`standard' > bm70_`standard' & !missing(bm_`standard', bm70_`standard')
	
	generate sv_`standard' = size_`standard'*10 + value_`standard'
}
tempfile sv
save `sv', replace
restore

merge m:1 證券代碼 mdate using `sv', keepusing(sv_*) 
quietly count if _merge!=3
if r(N)>0 {
	display as error "ERROR from genfact.do: Some observations cannot be matched."
	exit
}
else drop _merge
bysort 證券代碼 (年月日): generate 市值百萬元l1 = 市值百萬元[_n-1]
order 市值百萬元l1, after(市值百萬元)
foreach standard in ff tej {
	genvwmean vwret_`standard' if !missing(sv_`standard', 年月日), v(報酬率) w(市值百萬元l1) by(sv_`standard' 年月日)
}
keep 年月日 sv_* vwret_*
duplicates drop
preserve
genport, s(ff)
foreach f in smb hml {
	gen`f'
}
merge 1:1 年月日 using "./data/mkt.dta", keep(match master) nogenerate
foreach v of varlist * {
	quietly count if missing(`v')
	if r(N)>0 {
		display as result "WARNING from genfact.do: `v' has missing values."
	}
}
save "./data/factors_ff.dta", replace
export delimited "./data/factors_ff.csv", replace
restore
genport, s(tej)
foreach f in smb hml {
	gen`f'
}
merge 1:1 年月日 using "./data/mkt.dta", keep(match master) nogenerate
foreach v of varlist * {
	quietly count if missing(`v')
	if r(N)>0 {
		display as result "WARNING from genfact.do: `v' has missing values."
	}
}
save "./data/factors_tej.dta", replace
export delimited "./data/factors_tej.csv", replace
