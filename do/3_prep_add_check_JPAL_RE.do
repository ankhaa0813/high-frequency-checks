**# Bookmark #1
********************************************************************************
**     TITLE : Preparation for additional checks.do
**
**     PURPOSE : Merge the endline and baseline data and compare the results 
**                
**     AUTHOR : Ankhbayar.D
**
**     DATE : 
/*--------------------------------------------------------------*/
/*                   STRUCTURE OF THE DOCUMENT                  */
/*--------------------------------------------------------------*/

**# Table of Contents
** 1. Discrepancy Between Baseline and Endline
** 2. Duraion of each survey sections
** 3. Odd Survey End and Start Time
** 4. Shorter Survey Durations
** 5. Goods and production services 
** 6. Missing rate of key questions 

********************************************************************************
*------------------------------------------------------------------------------*


	* Load the main survey data
	use "$rawsurvey", clear
	
	local cutoff_time = clock("2024-11-09 00:00:00", "YMDhms")

// Drop observations where starttime is before the cutoff
	drop if submissiondate < `cutoff_time'
	drop if district==200 | district==100
	drop if internal_id=="100_211113"
	*drop if internal_id=="200_211122"

/*--------------------------------------------------------------*/
/*        1. Discrepancy Between Baseline and Endline           */
/*--------------------------------------------------------------*/

* Variables we are conducting cross-check across the baseline and endline
	su peop_hh hh_live bisp income_hh_total elect_connect spend_usually savings_avg

* Preserve current data in memory and load baseline dataset
preserve
		*import delimited "${cwd}/4_data/2_survey/P22015_Baseline_dataset_TEST.csv", clear
		
		use "${cwd}/4_data/2_survey/P22015_Baseline_dataset.dta", clear
		*------------------------------------------------------------------------------*
		* Rename variables to prepare for merging with endline dataset
		rename peop_hh peop_hh_23
		rename hh_live hh_live_23
		rename bisp bisp_23
		rename income_hh_total income_hh_total_23
		rename elect_connect elect_connect_23
		rename spend_usually spend_usually_23
		rename savings_avg savings_avg_23

		* Save baseline dataset as a temporary file for later merging
		tempfile temp_baseline

		*------------------------------------------------------------------------------*
		* Creating the id key for merging
		* Ensure client_cnic is stored as a string variable to facilitate extraction
		gen str_cnic = string(client_cnic, "%13.0f")

		* Extract the last 6 digits of the client_cnic variable
		gen last_6_cnic = substr(str_cnic, -6, 6)

		* Convert district_number to string to concatenate
		gen str_district = string(district_number, "%9.0f")

		* Concatenate last 6 digits of client_cnic with district_number with an underscore in between
		gen id_key =  str_district  + "_" + last_6_cnic

		* Keep only the necessary variables for merging
		rename client_cnic cnic 
		keep cnic peop_hh_23 hh_live_23 income_hh_total_23 elect_connect_23 spend_usually_23 savings_avg_23 id_key bisp_23 cnic 
		save "${cwd}/4_data/2_survey/P22015_Baseline_dataset_ID.dta", replace
		drop cnic
		save `temp_baseline', replace
		

restore 
rename internal_id id_key



*------------------------------------------------------------------------------*
* Merge baseline data with the main dataset using id_key as the key variable
merge m:1 id_key using `temp_baseline'

drop if _merge == 2


*------------------------------------------------------------------------------*
* Creating new discrepancy flag variables
gen a_peop_hh_bcc = 0
gen a_hh_live_bcc = 0
gen a_income_hh_total_bcc = 0
gen a_elect_connect_bcc = 0
gen a_savings_avg_bcc = 0
gen a_spend_usually_bcc = 0
gen a_bisp_bcc = 0

*------------------------------------------------------------------------------*

*** ONLY FOR TEST 
*// Step 1: Convert "yes"/"no" to 1/0 and replace in the original variables
*replace bisp_23 = cond(bisp_23 == "yes", "1", cond(bisp_23 == "no", "0", ""))
*replace elect_connect_23 = cond(elect_connect_23 == "yes", "1", cond(elect_connect_23 == "no", "0", ""))

// Step 2: Convert the variables to numeric (byte type)
*destring bisp_23, replace force
*destring elect_connect_23, replace force
*recast byte bisp_23
*recast byte elect_connect_23
// TEST
// Step 3: Add value labels
label define yes_no 0 "No" 1 "Yes"
label values bisp_23 yes_no
label values elect_connect_23 yes_no
***
* Calculating differences and setting flags for discrepancies

*** peop_hh: Number of people in household
gen diff_peop_hh = peop_hh - peop_hh_23
replace a_peop_hh_bcc = 1 if diff_peop_hh > 2 | diff_peop_hh < -2
replace a_peop_hh_bcc = 0 if client_type=="pilot"
replace a_peop_hh_bcc = 0 if diff_peop_hh==.

*** hh_live: Number of dependents (under age 16)
gen diff_hh_live = hh_live - hh_live_23
replace a_hh_live_bcc = 1 if diff_hh_live > 2 | diff_hh_live < -2
replace a_hh_live_bcc = 0 if client_type=="pilot"
replace a_hh_live_bcc = 0 if diff_hh_live==.

*** income_hh_total: Average monthly household income
gen diff_income_hh_total = 100 * (income_hh_total - income_hh_total_23) / income_hh_total_23
replace a_income_hh_total_bcc = 1 if diff_income_hh_total > 20 | diff_income_hh_total < -20
replace a_income_hh_total_bcc = 0 if client_type=="pilot"
replace a_income_hh_total_bcc = 0 if diff_income_hh_total==.

*** elect_connect: Electricity connection status
gen diff_elect_connect = elect_connect - elect_connect_23
replace a_elect_connect_bcc = 1 if diff_elect_connect!= 0
replace a_elect_connect_bcc = 0 if client_type=="pilot"
replace a_elect_connect_bcc = 0 if diff_elect_connect==.

*** savings_avg: Average monthly savings
gen diff_savings_avg = 100 * (savings_avg - savings_avg_23) / savings_avg_23
replace a_savings_avg_bcc = 1 if diff_savings_avg > 20 | diff_savings_avg < -20
replace a_savings_avg_bcc = 0 if client_type=="pilot"
replace a_savings_avg_bcc = 0 if diff_savings_avg==.

*** spend_usually: Average monthly spending on electricity
gen diff_spend_usually = 100 * (spend_usually - spend_usually_23) / spend_usually_23
replace a_spend_usually_bcc = 1 if diff_spend_usually > 20 | diff_spend_usually < -20
replace a_spend_usually_bcc = 0 if client_type=="pilot"
replace a_spend_usually_bcc = 0 if diff_spend_usually==.

*** bisp: BISP/AHSAS beneficiary status
gen diff_bisp = bisp - bisp_23
replace a_bisp_bcc = 1 if diff_bisp != 0
replace a_bisp_bcc = 0 if client_type=="pilot"
replace a_bisp_bcc = 0 if diff_bisp==.

*------------------------------------------------------------------------------*
* Calculate average discrepancy between baseline and endline
gen avg_bcc = (a_peop_hh_bcc + a_hh_live_bcc + a_income_hh_total_bcc + a_elect_connect_bcc + a_savings_avg_bcc + a_spend_usually_bcc + a_bisp_bcc) / 7

* Generate a flag for high average discrepancy
gen high_avg_discrepancy = 0
replace high_avg_discrepancy = 1 if avg_bcc > 0.5
replace high_avg_discrepancy = 0 if consent!=1
label variable high_avg_discrepancy "The average discrepancy between baseline and endline is above 0.5"

/*--------------------------------------------------------------*/
/*                2. Duraion of each survey sections            */
/*--------------------------------------------------------------*/


* Calculating durations for each section of the survey
destring duration, replace
replace duration = duration / 60 // Convert seconds to minutes

* Convert time stamps from string to numeric using destring
foreach stamp of varlist stamp_* {
    capture confirm variable `stamp'
    if !_rc {
        destring `stamp', replace // Convert the string variable to numeric in place using destring.
    }
}

* Calculate time differences between successive stamps
gen dur_consent = (stamp_2 - stamp_1) / 60      // Time spent during consent section, in minutes.
gen dur_basic = (stamp_3 - stamp_2) / 60        // Time spent on basic information section, in minutes.
gen dur_business_bac = (stamp_4 - stamp_3) / 60 // Time spent on business background section, in minutes.
gen dur_business_inv = (stamp_5 - stamp_4) / 60 // Time spent on business investment section, in minutes.
gen dur_electricity = (stamp_6 - stamp_5) / 60  // Time spent on electricity section, in minutes.
gen dur_solar = (stamp_7 - stamp_6) / 60        // Time spent on solar panels section, in minutes.
gen dur_saving = (stamp_8 - stamp_7) / 60       // Time spent on saving and consumption section, in minutes.
gen dur_insurance = (stamp_9 - stamp_8) / 60    // Time spent on insurance questions section, in minutes.
gen dur_climate = (stamp_10 - stamp_9) / 60     // Time spent on climate change awareness section, in minutes.
gen dur_weather = (stamp_11 - stamp_10) / 60    // Time spent on weather and clouds section, in minutes.
gen dur_trust = (stamp_12 - stamp_11) / 60      // Time spent on trust section, in minutes.
gen dur_extra = (stamp_14 - stamp_12) / 60      // Time spent on extra question section, in minutes.
gen dur_nrsp = (stamp_15 - stamp_14) / 60      // Time spent on NRSP questions

label variable dur_consent "Time spent during consent section, in minutes"
label variable dur_basic "Time spent on basic information section, in minutes"
label variable dur_business_bac "Time spent on business background section, in minutes"
label variable dur_business_inv "Time spent on business investment section, in minutes"
label variable dur_electricity "Time spent on electricity section, in minutes"
label variable dur_solar "Time spent on solar panels section, in minutes"
label variable dur_saving "Time spent on saving and consumption section, in minutes"
label variable dur_insurance "Time spent on insurance questions section, in minutes"
label variable dur_climate "Time spent on climate change awareness section, in minutes"
label variable dur_weather "Time spent on weather and clouds section, in minutes"
label variable dur_trust "Time spent on trust section, in minutes"
label variable dur_extra "Time spent on extra question section, in minutes"
label variable dur_nrsp  "Time spent on NRSP 1uestions, in minutes"

/*--------------------------------------------------------------*/
/*                3. Odd Survey End and Start Time              */
/*--------------------------------------------------------------*/
* Calculating odd timing of the survey started and ended
gen start_hour = hh(starttime)
gen end_hour = hh(endtime)

* Generate flags for odd start and end times
gen odd_start_time = 0
gen odd_end_time = 0
replace odd_start_time = 1 if start_hour < 8 | start_hour > 20
replace odd_end_time = 1 if end_hour < 8 | end_hour > 20
replace odd_start_time = 0 if consent!=1
replace odd_end_time = 0 if consent!=1


label variable odd_start_time "The survey start time is unusual (before 8 AM or after 8 PM)"
label variable odd_end_time "The survey end time is unusual (before 8 AM or after 8 PM)"

/*--------------------------------------------------------------*/
/*                4. Shorter Survey Durations                   */
/*--------------------------------------------------------------*/

* Calculating shorter survey duration
gen short_duration = 0
replace short_duration = 1 if duration < 40
replace short_duration = 0 if consent!=1
label variable short_duration "The survey duration is shorter than 40 minutes"



/*--------------------------------------------------------------*/
/*              5. Goods and production services                */
/*--------------------------------------------------------------*/

gen bus_logic_base=bus_goods_production+bus_services
gen bus_logic1= 0
replace bus_logic1 = 1 if bus_logic_base==0
replace bus_logic1 = 0 if consent!=1
label variable bus_logic1 "The business neither produces goods nor provides services"


/*--------------------------------------------------------------*/
/*              6. Missing rate of key questions                */
/*--------------------------------------------------------------*/


** KEY VARIABLES br elect_connect generator_own solar_own cc_heard nrsp_complaint_1
gen b_avg_no_responses = 1 - ( ///
    (cond(elect_connect == 999 | missing(elect_connect), 0, elect_connect)) + ///
    (cond(generator_own == 999 | missing(generator_own), 0, generator_own)) + ///
    (cond(solar_own == 999 | missing(solar_own), 0, solar_own)) + ///
    (cond(cc_heard == 999 | missing(cc_heard), 0, cc_heard)) + ///
    (cond(nrsp_complaint_1 == 999 | missing(nrsp_complaint_1), 0, nrsp_complaint_1)) ///
) / 5
label variable b_avg_no_responses "Average proportion of No responses for key variables"


* Save the final dataset
save "$rawsurvey", replace