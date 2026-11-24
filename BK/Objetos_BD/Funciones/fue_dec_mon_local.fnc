create or replace function it.fue_dec_mon_local
return number is
begin
  --return fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,pag_gen.FU_OBT_MON_LOCAL,null,null);
  return 0;
exception
  when others then
    raise_application_error(-20000,'Error al buscar los decimales de la Moneda Local. '||sqlerrm);
end;
/

