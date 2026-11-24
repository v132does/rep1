create or replace function it.fum_obt_fec_ini_cuota(p_cuenta in varchar2, p_cuota in number) return date is
  Result date;
begin
  if p_cuota = 1 then
     select mdoc.fec_inicio
       into result
       from md_cta_documentos mdoc
      where mdoc.nro_cuenta = p_cuenta;
  else
    select mdet.fec_vencimiento
      into result
      from md_doc_detalles mdet
     where mdet.nro_cuenta = p_cuenta
       and mdet.nro_cuota = p_cuota - 1; /*fec_vencimiento de la cuota anterior + 1*/
  end if;
  
  return(Result);
exception
  when others then
     return null;
end fum_obt_fec_ini_cuota;
/

