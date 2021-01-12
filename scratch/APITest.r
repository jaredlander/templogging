refresh_url <- 'https://api.ecobee.com/token'

# need a new token each time
token_request <- httr::POST(
    url=glue::glue("{refresh_url}?grant_type=refresh_token&code={Sys.getenv('ECOBEE_REFRESH_TOKEN')}&client_id={Sys.getenv('ECOBEE_API_KEY')}"), 
    encode='json'
)

access_token <- httr::content(token_request)$access_token

temp_all <- httr::GET(
    'https://api.ecobee.com/1/thermostat?format=json&body={"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":true,"includeSettings":true,"includeSensors":true,"includeWeather":true}}'
    , httr::add_headers(Authorization=glue::glue('Bearer {access_token}'))
    , encode='json'
)
therms_all <- httr::content(temp_all)
therms_all$thermostatList[[2]]$remoteSensors[[1]]$name
therms_all$thermostatList[[2]]$remoteSensors[[1]]$capability[[1]]$value
therms_all$thermostatList[[2]]$remoteSensors[[2]]$capability[[1]]$value


therms_all$thermostatList[[1]]$remoteSensors[[1]]$name
therms_all$thermostatList[[1]]$remoteSensors[[1]]$capability[[1]]$value
therms_all$thermostatList[[1]]$remoteSensors[[2]]$name
therms_all$thermostatList[[1]]$remoteSensors[[2]]$capability[[1]]$value
therms_all$thermostatList[[1]]$remoteSensors[[3]]$name
therms_all$thermostatList[[1]]$remoteSensors[[3]]$capability[[1]]$value

# time, hvac mode, sensor name, occupancy, humidity (if available), temperature, set temp (heat/cool),desired humidity, desired heat/cool range, fan mode, desired fan mode, runtime$rawTemperature, average of all sensors, lastServiceDate, vent, fanspeed, 

# get_sensor_values(therms_all$thermostatList[[1]]$remoteSensors[[2]])
get_sensor_values <- function(sensor)
{
    theName <- sensor$name
    type <- sensor$type
    inUse <- sensor$inUse
    
    stuff <- purrr::map_df(sensor$capability, tibble::as_tibble) %>% 
        dplyr::select(-id) %>% 
        tidyr::pivot_wider(names_from=type, values_from=value)
    
    dplyr::bind_cols(name=theName, type=type, in_use=inUse, stuff)
}

# get_sensor_readings(therms_all$thermostatList[[1]]$remoteSensors)
get_sensor_readings <- function(sensors)
{
    purrr::map_df(sensors, get_sensor_values)
}

# get_thermostat_readings(therms_all$thermostatList[[1]])
get_thermostat_readings <- function(thermostat)
{
    tibble::tibble(
        name=thermostat$name, time=thermostat$thermostatTime
        , actual_temperature=thermostat$runtime$actualTemperature/10
        , raw_temperature=thermostat$runtime$rawTemperature/10
        , humidity=thermostat$runtime$actualHumidity
        , desired_heat=thermostat$runtime$desiredHeat/10
        , desired_cool=thermostat$runtime$desiredCool/10
        , desired_humidity=thermostat$runtime$desiredHumidity
        , desired_dehumidity=thermostat$runtime$desiredDehumidity
        , desired_fan_mode=thermostat$runtime$desiredFanMode
        , desired_heat_range_low=thermostat$runtime$desiredHeatRange[[1]]/10
        , desired_heat_range_high=thermostat$runtime$desiredHeatRange[[2]]/10
        , desired_cool_range_low=thermostat$runtime$desiredCoolRange[[1]]/10
        , desired_cool_range_high=thermostat$runtime$desiredCoolRange[[2]]/10
    )
}

# get_thermostat_settings(therms_all$thermostatList[[1]])
get_thermostat_settings <- function(thermostat)
{
    tibble::tibble(
        hvac_mode=thermostat$settings$hvacMode
        , last_service_date=thermostat$settings$lastServiceDate
        , vent=thermostat$settings$vent
        , fan_min_on_time=thermostat$settings$fanMinOnTime
        , fan_speed=thermostat$settings$fanSpeed
    )
}
