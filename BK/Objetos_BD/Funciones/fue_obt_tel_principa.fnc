CREATE OR REPLACE FUNCTION IT.FUE_OBT_TEL_PRINCIPA
 (P_COD_PERSONA IN VARCHAR2
 )
 RETURN VARCHAR
 IS
V_AREA          BA_TELEFONOS.AREA%TYPE;
V_TELEFONO      BA_TELEFONOS.TELEFONO%TYPE;
V_EMA_GESTOR    BA_USUARIOS.dir_correo%type;
--DYDMR-11967 ITGF - Error GENERACION LIBRO IVA VENTAS NAF NOV/2019
function lf_obt_ema_gestor (p_cod_persona ba_personas.cod_persona%type) return varchar2 is
v_email ba_usuarios.dir_correo%type;
begin
  select b.dir_correo
  into v_email       
  from ge_clientes a
        -- usuario oficial
        left join ba_usuarios b on a.cod_usu_oficial = b.cod_usuario
   where a.cod_persona = p_cod_persona;
   
   return v_email;
exception
   when others then
     return null;
end;
     
Begin
    --Obtiene el Teléfono principal de la persona
    select area, telefono
    into v_area, v_telefono
    from ba_telefonos
    where cod_persona = p_cod_persona
    and principal = 'S';
    if v_area is not null then
        return '('||v_area||') '||v_telefono;
    elsif v_area is null then
        return v_telefono;
    else
        return null;
    end if;

exception
   when no_data_found then
     --DYDMR-11967 ITGF - Error GENERACION LIBRO IVA VENTAS NAF NOV/2019
     --return('Nro. de Teléfono no registrado en el Sistema.Cliente:'||P_COD_PERSONA);
     v_ema_gestor := lf_obt_ema_gestor(p_cod_persona);
     prg_ins_notificacion( trunc(sysdate), 
                           fug_obt_dir_correo, 
                           v_ema_gestor, 
                           'Cliente '||P_COD_PERSONA||' no tiene telefono principal cargado!',
                           'Email generado automaticamente por inconsistencia de datos en el proceso de cierre ITGF:'||CHR(10)||
                           'Cliente '||P_COD_PERSONA||' no tiene telefono principal cargado. Verifique.',
                           'FUE_OBT_TEL_PRINCIPA');
     return null;
   when too_many_rows then
     --DYDMR-11967 ITGF - Error GENERACION LIBRO IVA VENTAS NAF NOV/2019
     --return('Más de un Télefono marcado como Principal.Cliente:'||P_COD_PERSONA);
     V_EMA_GESTOR := lf_obt_ema_gestor(p_cod_persona);
     prg_ins_notificacion( trunc(sysdate), 
                           fug_obt_dir_correo, 
                           v_ema_gestor, 
                           'Cliente '||P_COD_PERSONA||' con mas de un telefono principal!',
                           'Email generado automaticamente por inconsistencia de datos en el proceso de cierre ITGF:'||CHR(10)||
                           'Cliente '||P_COD_PERSONA||' con mas de un telefono principal. Favor Ajustar.',
                           'FUE_OBT_TEL_PRINCIPA');
     return null;
End;
/

