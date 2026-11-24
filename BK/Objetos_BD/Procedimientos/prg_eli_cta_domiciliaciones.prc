create or replace procedure it.prg_eli_cta_domiciliaciones(p_nro_cuenta in varchar2, p_accion in varchar2) is
  --Inserta cuenta en log de Domiciliaciones--
  --Ref. p_accion : E=Eliminar / R-Rechazar--
begin
  --Insertar Cuentas Domiciliadas a Eliminar/Rechazar en el Log de cuentas--
  insert into ge_dom_ban_cuentas_log
  (nro_cuenta, estado, cod_persona, cod_per_pte_beneficiario, 
   nro_cta_beneficiario, fec_domiciliacion, cod_circuito)
   select x.nro_cuenta, p_accion, x.cod_persona, x.cod_per_pte_beneficiario, 
          x.nro_cta_beneficiario, x.fec_domiciliacion, x.cod_circuito
    from ge_dom_ban_cuentas x
   where x.nro_cuenta = p_nro_cuenta;
  
  --Elimina cta. si es R-Rechazo (Workflow) - Si es E-Eliminacion elimina en el formulario de Mant.--
  if p_accion = 'R' then --R-Rechazo (Workflow) 
     delete from ge_dom_ban_cuentas y
      where y.nro_cuenta = p_nro_cuenta;
  end if;
exception
  when others then
    raise_application_error(-20000,'Error en: prg_ins_log_domiciliaciones '||sqlerrm);
end;
/

