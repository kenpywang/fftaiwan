* Preamble  --------------------------------------------------------------------

foreach obj in mata matrix programs frames {
	clear `obj'
}
set more off
pwd

local tej_fund "" // Put the path of the fundamental data in a CSV file here.
local tej_stock_msf "" // Puth the path of the monthly stock data in a CSV file here. 

capture program drop genbe
program define genbe

	version 16.0
	syntax, MONth(integer)
	
	quietly count if mod(年月, 100) != 月份
	if r(N)>0 {
		display as error "ERROR from genbp.do: Some months in the 年月s do not equal to 月份s."
		exit
	}
	else keep if 月份==`month'
	generate 年 = floor(年月/100), before(年月)
	isid 證券代碼 年
	keep 證券代碼 年 年月 股東權益總額 非控制權益 特別股股本 季底普通股市值
	foreach v of varlist 非控制權益 特別股股本 {
		replace `v' = 0 if missing(`v')
	}
	generate 淨值 = 股東權益總額 - 非控制權益 - 特別股股本
	drop 股東權益總額 非控制權益 特別股股本

end

capture program drop genbm
program define genbm

	version 16.0
	syntax, MONth(integer)
	
	generate 淨值市價比 = (淨值/1000)/市值百萬元
	replace 淨值市價比 = 淨值/季底普通股市值 if missing(淨值市價比)
	replace 淨值市價比 = . if 淨值 < 0
	preserve
	keep 證券代碼 年 淨值市價比
	egen id = group(證券代碼)
	xtset id 年
	generate YL1淨值市價比 = L1.淨值市價比
	rename *淨值市價比 *淨值市價比`month'
	drop id
	xtset, clear
	save "./data/bm`month'.dta", replace
	restore 
	bysort 年 (淨值市價比): egen n = count(市值百萬元)
	generate isneg_淨值 = 淨值<0 & !missing(淨值)
	generate ispos_淨值 = 淨值>=0 & !missing(淨值)
	foreach part in neg pos {
		by 年: egen n`part'_淨值 = total(is`part'_淨值)
		drop is`part'_淨值
	}
	by 年: egen min = min(淨值市價比)
	forvalues p = 5(5)95 {
		by 年: egen p`p' = pctile(淨值市價比), p(`p')
	}
	by 年: egen max = max(淨值市價比)
	keep 年 n-max
	duplicates drop
	isid 年
	save "./data/bm`month'bp.dta", replace
	
end

* Main ---------------------------------------------------------------------------

* Breakpoints of Market Capitalizations

import delimited "`tej_stock_msf'", stringcols(1) varnames(1) case(preserve) encoding("Big5") clear
quietly count if 市值百萬元 < 0
if r(N)>0 {
	display as error "ERROR from genbp.do: Some 市值百萬元s are negative."
	exit
}
else keep 證券代碼 年月 市值百萬元
duplicates drop
isid 證券代碼 年月
generate 年 = floor(年月/100), before(年月)
save "./data/me.dta", replace
bysort 年月 (市值百萬元): egen n = count(市值百萬元)
by 年月: egen min = min(市值百萬元)
forvalues p = 5(5)95 {
	by 年月: egen p`p' = pctile(市值百萬元), p(`p')
}
by 年月: egen max = max(市值百萬元)
keep 年月 n-max
duplicates drop
isid 年月
save "./data/mebp.dta", replace

* Breakpoints of Book-to-Market Ratios

** Fama-French Version

import delimited "`tej_fund'", stringcols(1) varnames(1) case(preserve) encoding("Big5") clear
genbe, mon(12)
merge 1:1 證券代碼 年月 using "./data/me.dta", keep(match master)
genbm, mon(12)

** TEJ Version

import delimited "`tej_fund'", stringcols(1) varnames(1) case(preserve) encoding("Big5") clear
genbe, mon(3)
preserve
use "./data/me.dta", clear
keep if mod(年月, 100) == 5
isid 證券代碼 年
drop 年月
tempfile me5
save `me5', replace
restore
merge 1:1 證券代碼 年 using `me5', keep(match master)
genbm, mon(5)
