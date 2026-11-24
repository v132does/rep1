create or replace force view it.simgia_afdmae_anterior as
select "AFDNRO","AFDTIPOR","AFDMONEDA","AFDVTO","AFDMONTO","AFDSUC","AFDCUENTA","AFDFEINI","AFDDEVENG","AFDFCHCONT","AFDTASA","DOC_ESTADO","DET_ESTADO","FECHA_HIS"
from SIMGIA_AFDMAE_bkp a;

