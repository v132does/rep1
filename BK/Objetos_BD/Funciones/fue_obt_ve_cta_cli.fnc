CREATE OR REPLACE FUNCTION IT.FUE_OBT_VE_CTA_CLI
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE
 ,P_COD_PERSONA IN BA_USUARIOS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
-- Esta Funcion retorna S o N, segun el usuario pueda o no
-- ver las cuentas de los funcionarios
   v_vectemp ba_usuarios.ver_cta_empleados%type := 'N';
   v_cdperso ba_usuarios.cod_persona%type;
   v_esemple varchar2(1) := 'N';
Begin
   v_esemple := fug_es_empleado(p_cod_persona);
   If v_esemple = 'N' Then
      v_vectemp := 'S';
   Else
      Select nvl(ver_cta_empleados, 'N'), cod_persona
        into v_vectemp, v_cdperso
        from ba_usuarios
       where cod_usuario = p_cod_usuario;
      -- Si el usuario no puede ver cuentas de empleados, pero el
      -- codigo de persona que desea ver es su propio codigo, entonces
      -- si puede ver
      if v_vectemp = 'N' then
         if v_cdperso = p_cod_persona then
            v_vectemp := 'S';
         end if;
      end if;
   End If;
   Return v_vectemp;
exception
   when others then
      return 'N';
End;
/

