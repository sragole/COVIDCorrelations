### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ d7bf8b8d-de6b-4783-895c-e2f5a1850067
begin
	import Pkg
	Pkg.activate()
	Pkg.add("Plots")
	Pkg.add("CSV")
	Pkg.add("DataFrames")
	Pkg.add("Dates")
	Pkg.add("ImageFiltering")
	Pkg.add("OffsetArrays")
	Pkg.add("Statistics")
	Pkg.add("PlutoUI")
end

# ╔═╡ ef23d264-448e-11eb-10f8-ad25ae5f244d
begin
	using Plots
	using CSV
	using DataFrames
	using Dates
	using ImageFiltering
	using OffsetArrays
	using Statistics
	using PlutoUI
end

# ╔═╡ e2635196-448c-11eb-2877-c5735be35d80
md"""
## California COVID correlations

This notebook will take COVID case, hospitalization, and death data from California counties and attempt to find a lagged CFR in the style of Trevor Bedford's [analysis](https://twitter.com/trvrb/status/1326404889438801921).

The main idea is that a reasonably stable fraction of cases on a given day will die from COVID but that it takes some time for the disease to progress, so the death rate lags the case rate. Of course, we don't assume that we are identifying all the cases, so the lagged case-fatality-rate (CFR) here is not a real CFR. It is likely a big overestimate, but if it is relatively stable, it will allow us to forecast deaths 15+ days ahead of today.
"""

# ╔═╡ cdec3534-43f1-4726-af95-d82e32f3a0cb
begin
	state_case_data = CSV.read("covid19cases_test.csv", DataFrame)
	county_list = unique(state_case_data[!, :area])
	state_hosp_data = CSV.read("statewide-covid-19-hospital-county-data.csv", DataFrame)
	county_list_2 = unique(state_hosp_data[!, :county])
	county_list = intersect(county_list, county_list_2)
end;

# ╔═╡ 9887d642-8387-477c-991c-4756bc137252
md"""
Using the dropdown, select the county to investigate. This analysis works best with big populations, so smaller counties may not work as well.
"""

# ╔═╡ 3ac6e767-2df5-4969-8582-11312228f534
md"""
## Data from $(@bind county_name Select(county_list, default="Santa Clara")) county

"""

# ╔═╡ 1d7590fd-8295-4964-b368-4629b1b3137c
begin
	offset = 3 #recent data is somewhat unreliable
	county_case_data  = filter(row -> row.area == county_name, state_case_data)
	county_case_dates = Date.(county_case_data[!, "date"][1:end-offset])
	county_cases = county_case_data[!, "cases"][1:end-offset]						
	county_deaths = county_case_data[!, "deaths"][1:end-offset]
end;

# ╔═╡ 7a75c70f-e7d5-4505-8b6e-128e3a9c2e0b
begin
	county_hosp_data  = filter(row -> row.county == county_name, state_hosp_data)
	county_hosp_dates = Date.(county_hosp_data[!, "todays_date"])
	county_tot_patients= (county_hosp_data[!, "hospitalized_covid_confirmed_patients"] 							)#.+county_hosp_data[!, "hospitalized_suspected_covid_patients"])
	
	county_icu_cases = (county_hosp_data[!, "icu_covid_confirmed_patients"] 							.+county_hosp_data[!, "icu_suspected_covid_patients"])
	county_non_icu = county_tot_patients-county_icu_cases
end;

# ╔═╡ 8f0fce44-46ed-11eb-395c-b3072d1362e3
md"""
As one can see below, the case reporting data has artificial feautures due to a relative lack of reporting on Sundays. To correct for this, we'll take the 7-day average looking backwards.
"""

# ╔═╡ 9685d04e-4493-11eb-0db5-c35b82182d7f
begin
	StartDate = Date(2020,6,1);
	case_start_ind = findfirst(x -> x==StartDate, county_case_dates);
	hosp_start_ind = findfirst(x -> x==StartDate, county_hosp_dates);
end;

# ╔═╡ f7923db6-448f-11eb-0e94-e77b1a911cff
begin
	plotly()
	plot(county_case_dates[case_start_ind:end], 
		county_cases[case_start_ind:end], label = "New Cases")
end

# ╔═╡ 2fac8934-4494-11eb-0219-7f1d44649362
kernel = OffsetArray(fill(1/7, 7), -6:0);

# ╔═╡ 110729c7-6d6e-4efc-939f-d945a6d5ee12
county_moving_avg = imfilter(county_cases[case_start_ind:end], kernel);

# ╔═╡ 257048ea-4495-11eb-0b21-f353c7997010
begin
	plotly()
	plot(county_case_dates[case_start_ind:end], county_moving_avg, label = "Avg. Cases", legend=:topleft)
	plot!(county_case_dates[case_start_ind:end], 
		county_cases[case_start_ind:end], label = "New Cases")
end

# ╔═╡ 4efe6d30-4498-11eb-2e05-6924e9b3aa6a
begin
	county_avg_deaths = imfilter(county_deaths[case_start_ind:end],kernel)
	compMovingAvg = imfilter(county_cases[case_start_ind:end], kernel);
end;

# ╔═╡ 24d95b88-0521-49b6-9258-a96b10a8e541
md"""
## Comparing lagged cases with deaths
"""

# ╔═╡ f6f679d8-449a-11eb-1967-3da2b02ef0dc
@bind lag Slider(5:30, default=17, show_value=true)

# ╔═╡ 681f0498-449b-11eb-2dee-7dd6d54dfc4e
@bind lag_cfr Slider(0.001:0.001:0.03, default=0.018, show_value=true)

# ╔═╡ eed3fb32-46ed-11eb-13f6-0d79c4527fb0
md"""
Given the population of $(county_name) county, the average deaths are still fairly jagged because we still have small numbers. This death count in the county itself doesn't track the lagged case rate as well as people have seen using larger populations. Here I'm guessing we're seeing the inhomogeneity of COVID, e.g., cases counts could go up in low-risk populations and thus not see deaths rise until quite a bit later or conversely a small outbreak at a long-term care facility could lead to a lot of deaths.

Still the general trend is there, when cases rise sharply, deaths rise about $lag days later. The current fit predicts that for 100 new, identified cases, $(round((lag_cfr*100)*10)/10) people will die from COVID.
"""

# ╔═╡ 5b04aebe-4498-11eb-1309-93cbca18c737
begin
	plot(county_case_dates[case_start_ind:end]+Day(lag), lag_cfr*compMovingAvg[1:end], 
		label = "Estimated deaths", legend=:topleft)
	plot!(county_case_dates[case_start_ind:end], 
		county_avg_deaths, label = "County deaths")
end

# ╔═╡ a14162e8-46ee-11eb-3edb-8f55a7565c4b
md"""
Having made our rough fit, we can project deaths going foreward by taking recent case counts, multiplying by the lagged CFR and shifting forward in time. Below we see that by $(county_case_dates[end-5]+Day(lag)), there should be roughly $(round(lag_cfr*compMovingAvg[end-5])) deaths per day.

This prediction should be an overestimate given the presence of vaccines, but if the cases are concentrated in the unvaccinated, it might not be.
"""

# ╔═╡ 35eb6a82-449a-11eb-1f5e-ebe3e5fa4fb6
begin
	plotly()
	plot(county_case_dates[end-lag:end-5]+Day(lag), 
		lag_cfr*compMovingAvg[end-lag:end-5], 
		label = "Estimated deaths",
		legend=:topleft)
end

# ╔═╡ 291c556e-44b6-11eb-0666-df947594a060
md"""
## Comparing lagged cases to hospitalization
Now we're going to add in the number of hospitalized people. By similar arguments, a fraction of cases on a given day will eventually need hospital beds or potentially an ICU bed. We can also fit the averaged new case data to these figures as well.

Note, the adjustment factor here is not a simple hospitalization rate since people stay for multiple days in the ICU or hospital. If we knew the average time a COVID patient spends in the ICU or hospital, we could figure out the case/hospital bed or case/ICU ratio, but this would still have the issues from lack of testing and thus could not be used to predict how frequently a COVID infection requires hospital services.

Nevertheless, we can still use these correlation to predict future hospital need.
"""

# ╔═╡ ba472a38-46ef-11eb-21e6-97331ae5e715
md"""
Below, we see much better agreement between the scaled, lagged case numbers and the number of ICU patients.

However, somewhere in mid-December, just as ICUs began to approach capacity, we can see a clear change in the rate of people admitted. This may have arisen for many reasons, two of the most obvious would be only admitting the most severe cases to the ICU to reserve beds or an increase in cases from increased testing as people prepared for the holidays. The degree to which the deaths tracked cases during the same period could provide some evidence for the former vs. the latter.
"""

# ╔═╡ 3fd3dce4-44b8-11eb-0f23-93765a452257
@bind icu_lag Slider(1:20, default=15, show_value=true)

# ╔═╡ f8fffc76-44b7-11eb-3de5-9d2a8a97ca11
@bind icu_rate Slider(0.0:0.01:.3, default = 0.19, show_value=true)

# ╔═╡ 2a54ec88-44b7-11eb-196d-f7844a62e8f6
begin
	plotly()
	plot(county_hosp_dates[hosp_start_ind:end], county_icu_cases[hosp_start_ind:end], label = "ICU patients", legend=:topleft)
	plot!(county_case_dates[case_start_ind:end]+Day(icu_lag),
		icu_rate*compMovingAvg, 
		label = "Scaled, lagged cases", legend=:topleft)
	#plot!(county_dates, county_icu_cases)
end

# ╔═╡ b5fb79f2-44bf-11eb-025b-ed9492e39ade
@bind hosp_lag Slider(1:20, default=13, show_value=true)

# ╔═╡ 30323758-44c0-11eb-0df3-1ddd46872b74
md"""
If we assume the average ICU patient spends 5 days there, we predict that ~$(round(icu_rate*100/5)) % of identified COVID cases need ICU beds.

We can also predict that on $(county_case_dates[end]+Day(hosp_lag)) there will be $(round(icu_rate*compMovingAvg[end])) ICU patients hospitalized with COVID19
"""

# ╔═╡ 03f58904-46f0-11eb-08bb-035012ae329d
md"""
### Non-ICU patients
We repeat the analysis with non-ICU COVID patients and see our best correlation yet. The lag is only $hosp_lag days, so our predictive powers are limited, however they show a clear indication that rising cases leads to rising COVID+ patients who are hospitalized.
"""

# ╔═╡ c0b2387c-44bf-11eb-31d1-3f403a6067f3
@bind hosp_rate Slider(0.0:0.01:.6, default = 0.47, show_value=true)

# ╔═╡ f37730a2-44b8-11eb-18d2-670aa5a0209e
begin
	plot(county_hosp_dates[hosp_start_ind:end], 
		county_non_icu[hosp_start_ind:end], label= "Non-ICU Patients")
	plot!(county_case_dates[case_start_ind:end]+Day(hosp_lag),
		hosp_rate*compMovingAvg[1:end], 
		label = "Scaled, lagged cases", legend=:topleft)
	
end

# ╔═╡ f3525c1c-44bf-11eb-0619-4f99561f4a6b
md"""
If we assume the average hospital stay is 5 days, each identified COVID case as a $(round(hosp_rate/5*100)) % chance of needing a hospital bed.
"""

# ╔═╡ ede8c6f0-51d8-11eb-2681-cb27cee40af5
md"""
Current prediction is that on $(county_case_dates[end]+Day(hosp_lag)) there will be $(round(hosp_rate*compMovingAvg[end])) non-ICU patients hospitalized with COVID19
"""

# ╔═╡ b79d0f23-c592-4e03-b9e9-dc61b3cedb6e
md"""
#### Import statements and helper code
"""

# ╔═╡ 2f74be36-44ae-11eb-278d-9db0cdf4a98b
begin
	state_cases_deaths_url = "https://data.chhs.ca.gov/dataset/f333528b-4d38-4814-bebb-12db1f10f535/resource/046cdd2b-31e5-4d34-9ed3-b48cdbc4be7a/download/covid19cases_test.csv"
	download(state_cases_deaths_url,  "covid19cases_test.csv")
	state_hosp_url = "https://data.chhs.ca.gov/dataset/2df3e19e-9ee4-42a6-a087-9761f82033f6/resource/47af979d-8685-4981-bced-96a6b79d3ed5/download/covid19hospitalbycounty.csv"
	download(state_hosp_url,  "covid19hospitalbycounty.csv")
end;

# ╔═╡ Cell order:
# ╟─e2635196-448c-11eb-2877-c5735be35d80
# ╠═d7bf8b8d-de6b-4783-895c-e2f5a1850067
# ╠═ef23d264-448e-11eb-10f8-ad25ae5f244d
# ╠═cdec3534-43f1-4726-af95-d82e32f3a0cb
# ╟─9887d642-8387-477c-991c-4756bc137252
# ╟─3ac6e767-2df5-4969-8582-11312228f534
# ╠═1d7590fd-8295-4964-b368-4629b1b3137c
# ╠═7a75c70f-e7d5-4505-8b6e-128e3a9c2e0b
# ╟─8f0fce44-46ed-11eb-395c-b3072d1362e3
# ╟─f7923db6-448f-11eb-0e94-e77b1a911cff
# ╠═9685d04e-4493-11eb-0db5-c35b82182d7f
# ╠═2fac8934-4494-11eb-0219-7f1d44649362
# ╠═110729c7-6d6e-4efc-939f-d945a6d5ee12
# ╠═257048ea-4495-11eb-0b21-f353c7997010
# ╟─4efe6d30-4498-11eb-2e05-6924e9b3aa6a
# ╟─24d95b88-0521-49b6-9258-a96b10a8e541
# ╟─eed3fb32-46ed-11eb-13f6-0d79c4527fb0
# ╠═f6f679d8-449a-11eb-1967-3da2b02ef0dc
# ╠═681f0498-449b-11eb-2dee-7dd6d54dfc4e
# ╟─5b04aebe-4498-11eb-1309-93cbca18c737
# ╟─a14162e8-46ee-11eb-3edb-8f55a7565c4b
# ╟─35eb6a82-449a-11eb-1f5e-ebe3e5fa4fb6
# ╟─291c556e-44b6-11eb-0666-df947594a060
# ╟─ba472a38-46ef-11eb-21e6-97331ae5e715
# ╠═3fd3dce4-44b8-11eb-0f23-93765a452257
# ╠═f8fffc76-44b7-11eb-3de5-9d2a8a97ca11
# ╠═2a54ec88-44b7-11eb-196d-f7844a62e8f6
# ╟─30323758-44c0-11eb-0df3-1ddd46872b74
# ╟─03f58904-46f0-11eb-08bb-035012ae329d
# ╠═b5fb79f2-44bf-11eb-025b-ed9492e39ade
# ╠═c0b2387c-44bf-11eb-31d1-3f403a6067f3
# ╟─f37730a2-44b8-11eb-18d2-670aa5a0209e
# ╟─f3525c1c-44bf-11eb-0619-4f99561f4a6b
# ╟─ede8c6f0-51d8-11eb-2681-cb27cee40af5
# ╟─b79d0f23-c592-4e03-b9e9-dc61b3cedb6e
# ╠═2f74be36-44ae-11eb-278d-9db0cdf4a98b
