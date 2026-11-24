create or replace package body it.PAP_AFD is
--Verificar si es un prestamo AFD
FUNCTION FU_VER_PRE_AFD
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
  P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL)

 RETURN BOOLEAN
 IS
 v_cod_modulo    pr_cta_prestamos.cod_modulo%type;
 v_cod_modalidad pr_cta_prestamos.cod_modalidad%type;
 v_nro_solicitud pr_cta_prestamos.nro_solicitud%type;
Begin
  --Obtener datos de la cuenta/solicitud
  If p_nro_cuenta is not null then
    Begin
      select cod_modulo, cod_modalidad, nro_solicitud
        into v_cod_modulo,v_cod_modalidad, v_nro_solicitud
        from pr_cta_prestamos
       where nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        raise_application_error(-20000,'FU_VER_PRE_AFD '||'La cuenta no existe');
    end;
  elsif p_nro_solicitud is not null then
    Begin
      select cod_modulo, cod_modalidad
        into v_cod_modulo,v_cod_modalidad
        from pr_solicitudes
       where nro_solicitud = p_nro_solicitud;
      v_nro_solicitud := p_nro_solicitud;
    exception
      when no_data_found then
        raise_application_error(-20000,'FU_VER_PRE_AFD '||'La solicitud no existe');
    end;
  End if;
  If fug_obt_pardinamico('MOD_PRE_AFD',v_cod_modulo,v_cod_modalidad,null,null) = 'S' then
    return true;
  else
    return false;
  end if;
end;
--Verificar si es tiene impuesto AFD
FUNCTION FU_VER_IMP_AFD
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
  P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE DEFAULT NULL)

 RETURN BOOLEAN
 IS
 v_cod_modulo    pr_cta_prestamos.cod_modulo%type;
 v_cod_modalidad pr_cta_prestamos.cod_modalidad%type;
 v_nro_solicitud pr_cta_prestamos.nro_solicitud%type;
 v_cod_tra_iva   pr_sol_cargos.cod_transaccion%type;
 v_existe        varchar2(1) := 'N';
Begin
  --Obtener datos de la cuenta/solicitud
  If p_nro_cuenta is not null then
    Begin
      select cod_modulo, cod_modalidad, nro_solicitud
        into v_cod_modulo,v_cod_modalidad, v_nro_solicitud
        from pr_cta_prestamos
       where nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        raise_application_error(-20000,'FU_VER_PRE_AFD '||'La cuenta no existe');
    end;
  elsif p_nro_solicitud is not null then
    Begin
      select cod_modulo, cod_modalidad
        into v_cod_modulo,v_cod_modalidad
        from pr_solicitudes
       where nro_solicitud = p_nro_solicitud;
      v_nro_solicitud := p_nro_solicitud;
    exception
      when no_data_found then
        raise_application_error(-20000,'FU_VER_PRE_AFD '||'La solicitud no existe');
    end;
  End if;
  If fug_obt_pardinamico('MOD_PRE_AFD',v_cod_modulo,v_cod_modalidad,null,null) = 'S' then
    v_cod_tra_iva := fug_obt_pardinamico('COD_TRA_IVA_AFD');
    --Verificar si tiene el cargo del iva AFD
    begin
      select 'S'
        into v_existe
        from pr_sol_cargos
       where nro_solicitud = v_nro_solicitud
         and cod_transaccion = v_cod_tra_iva;
    exception
      when no_data_found then
         v_existe := 'N';
    end;
  End if;
  If v_existe = 'S' then
    return true;
  else
    return false;
  end if;
end;
end PAP_AFD;
/

