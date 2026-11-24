CREATE OR REPLACE FUNCTION IT.FUE_OBT_TIP_RELACION
 (P_NRO_CUENTA IN GE_CTA_CLIENTES.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS

V_RELACION GE_CTA_CLIENTES.RELACION%TYPE;
v_nro_cuenta GE_CTA_CLIENTES.Nro_Cuenta%TYPE;
v_count number;
Begin
    --Obtiene el Codigo del grupo al cual pertenece el usuario
    select count(1)
    into v_count
    from ge_cta_clientes
    where nro_cuenta = p_nro_cuenta;
    
    if v_count>1 then 
       
        select relacion, nro_cuenta
          into V_RELACION, v_nro_cuenta
          from ge_cta_clientes
          where nro_cuenta = p_nro_cuenta
            and relacion <> 'P'
            group by relacion, nro_cuenta;
            return v_relacion;
            
                   
    elsif v_count = 1 then
    
        select relacion, nro_cuenta
          into V_RELACION, v_nro_cuenta
          from ge_cta_clientes
          where nro_cuenta = p_nro_cuenta
            group by relacion, nro_cuenta;
            return v_relacion;
     
    elsif v_count = 0 then
    
          return null;
          
     end if;
            
    exception
       when no_data_found then
           return('');
       when too_many_rows then
            return('Y');
End;
/

