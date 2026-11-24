CREATE OR REPLACE FUNCTION IT.FUE_OBT_VER_MOV_FUN
 (P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE default null -- Codigo del Usuario que esta logeado en el sistema
 ,P_COD_USU_MOV IN BA_USUARIOS.COD_USUARIO%TYPE  -- Codigo del Usuario del Movimiento
 ,P_COD_PERSONA IN BA_USUARIOS.COD_PERSONA%TYPE  -- Codigo de Persona desde el cual se consulta
 )
 RETURN VARCHAR2
 IS
-- OMM 16/03/2016 Esta Funcion retorna S o N, segun el usuario pueda o no ver los movimientos de RRHH
   v_usu_mov_rrhh   varchar2(1) := 'N';
   v_ver_cta_fun    varchar2(1) := 'N';
   v_es_funcionario varchar2(1) := 'N';
Begin
   v_es_funcionario := fug_es_empleado(P_COD_PERSONA);
   if v_es_funcionario = 'S' then
        Begin
           Select 'S'
             into v_usu_mov_rrhh
             from ba_usuarios u, ba_areas a
            where u.cod_oficina = a.cod_oficina
              and u.cod_area    = a.cod_area
              and instr(fug_obt_pardinamico('ARE_RRHH',null,null,null,a.cod_oficina), a.cod_area) > 0
              and u.cod_usuario = P_COD_USU_MOV ;

         exception
            when others then
               v_usu_mov_rrhh := 'N' ;
         end ;

         IF v_usu_mov_rrhh = 'S' THEN
             Begin
               Select nvl(ver_cta_empleados, 'N')
                 into v_ver_cta_fun
                 from ba_usuarios
                 where cod_usuario = nvl(P_COD_USUARIO, user);

             exception
                when others then
                   v_ver_cta_fun := 'N' ;
             end ;
          ELSE
             v_ver_cta_fun := 'S' ;
          END IF ;
      else
         v_ver_cta_fun := 'S' ;
      end if; 
      
   Return v_ver_cta_fun;
exception
   when others then
      return 'N';
End;
/

