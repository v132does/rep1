create or replace function it.fut_obt_nro_doc_enviar(p_nro_documento in varchar2, p_cod_persona in varchar2)
return number is
begin
 if pat_imp.FU_val_NUMERO(p_nro_documento) = 0 then
    return to_number(p_cod_persona) * -1;
 else
    return to_number(p_nro_documento);
 end if;
end fut_obt_nro_doc_enviar;
/

