CREATE OR REPLACE PROCEDURE IT.PRG_HAB_SEC_USUARIOS
 IS
   --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
   --Habilita uso secuencia para hora usuarios por secuencia--
   v_lugar  varchar2(50);
   v_cod_usuario ge_par_usuarios.cod_usuario%type;

   --Cursor Principal--
   cursor c_usu_uti_secuencia is
     select a.cod_usu_pivot cod_usuario, a.rowid registro
       from ge_con_par_usuarios a
      where nvl(a.ind_uti_secuencia,'N') = 'N';

BEGIN
  for usu in c_usu_uti_secuencia loop
      --Habilita secuencia--
      v_lugar := 'Habilita Secuencia';
      v_cod_usuario := usu.cod_usuario;
      update ge_con_par_usuarios x
         set x.ind_uti_secuencia = 'S'
       where x.cod_usu_pivot = v_cod_usuario;
      PRG_ENV_MAI_ALE_ATM('AVISO USUARIO '||v_cod_usuario||': Habilita modo Secuencia. Cambio de parametro IND_UTI_SECUENCIA de N a S',
                             USER, trunc(sysdate));
  end loop;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en PRG_HAB_SEC_USUARIOS-'||v_lugar||'-'||sqlerrm);
END;
/

