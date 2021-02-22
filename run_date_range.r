# aws.s3::save_object(object='country/2021-01-14.csv', bucket=Sys.getenv('BUCKET_NAME'), file='data/2021-01-14.csv')

for(the_date in seq(from=lubridate::ymd('20210101'), to=lubridate::today(), by=1))
{
    print(class(lubridate::as_date(the_date)))
    process_date <- lubridate::as_date(the_date)
    print(process_date)
    tar_make(callr_function=NULL)
}
