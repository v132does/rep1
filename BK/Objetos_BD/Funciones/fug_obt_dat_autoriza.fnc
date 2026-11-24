CREATE OR REPLACE FUNCTION IT.FUG_OBT_DAT_AUTORIZA
 (P_INDICADOR IN VARCHAR2
 ,P_COD_PERSONA IN VARCHAR2
 ,P_NRO_CUENTA IN VARCHAR2
 )
 RETURN VARCHAR2
 IS

V_COD_PERSONA VARCHAR2(10);
V_NOMBRE BA_PERSONAS.NOM_COMPLETO%TYPE;
V_NRO_CUENTA VARCHAR2(15);
V_DENOMINACION GE_CUENTAS.DENOMINACION%TYPE;
BEGIN
   if P_COD_PERSONA is not null and p_indicador = 'N' then
      V_COD_PERSONA := P_COD_PERSONA;
      -- consultar el nombre de la persona
      select nom_completo
      into v_nombre
      from ba_personas
      where cod_persona = P_COD_PERSONA;
   end if;
   if p_nro_cuenta is not null and p_indicador IN ('C', 'D') then
      -- buscar principal
    select ge_cta_clientes.cod_persona,
           ge_cuentas.nro_cuenta,
           ge_cuentas.denominacion,
           ba_personas.nom_completo
      into v_cod_persona,
           v_nro_cuenta,
           v_denominacion,
           v_nombre
      from ba_personas,
           ge_cuentas,
           ge_cta_clientes
     where ge_cuentas.nro_cuenta = P_NRO_CUENTA
       and ba_personas.cod_persona = ge_cta_clientes.cod_persona
       and ge_cta_clientes.nro_cuenta = ge_cuentas.nro_cuenta
       and ge_cta_clientes.relacion = 'P';
   end if;

    if P_INDICADOR = 'N' then
    -- N indica, verificar si el usuario esta autorizado a ver el nombre del cliente
       begin
          if fue_obt_ve_cta_cli(user,v_cod_persona) = 'N' then
             v_nombre := 'Funcionario';
          elsif fug_cli_confidencial(v_cod_persona) = 'N' then
                v_nombre := 'Cliente confidencial';
          end if;
          return v_nombre;
       exception
          when no_data_found then
          return null;
       end;
    
    elsif P_INDICADOR = 'C' then
    -- C indica, verificar si el usuario esta autorizado a ver la cuenta del cliente
       begin
          if fue_obt_ve_cta_cli(user,v_cod_persona) = 'N' or
             fug_cli_confidencial(v_cod_persona) = 'N' then
                v_nro_cuenta := '**********';
          end if;
          return v_nro_cuenta;
       exception
          when no_data_found then
          return null;
       end;
    elsif P_INDICADOR = 'D' then
    -- D indica, verificar si el usuario esta autorizado a ver la denominacion del cliente
       begin
          if fue_obt_ve_cta_cli(user,v_cod_persona) = 'N' then
                v_denominacion := 'Funcionario';
          elsif fug_cli_confidencial(v_cod_persona) = 'N' then
                v_denominacion := 'Cliente confidencial';
          end if;
          return v_denominacion;
       exception
          when no_data_found then
          return null;
       end;
    end if;
END;
/

