CREATE OR REPLACE PROCEDURE IT.PRG_INI_SEC_USUARIOS IS
   --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
   -- Reinicializa Secuencia en FIN de DIA--
   v_lugar  varchar2(50);
   v_segundo number;
   v_cod_usuario ge_par_usuarios.cod_usuario%type;
   v_cod_usu_inicial ge_par_usuarios.cod_usuario%type;
   --Cursor Principal--
   cursor c_usu_uti_secuencia is
     select a.cod_usu_pivot cod_usuario, a.cod_sec_utilizada nom_secuencia,
            a.rowid registro
       from ge_con_par_usuarios a
      where nvl(a.ind_uti_secuencia,'N') = 'S';

BEGIN
    for usu in c_usu_uti_secuencia loop
        --Inicializa secuencia--
        v_lugar := 'Inicializa Secuencia';
        v_cod_usuario := usu.cod_usuario;
        v_cod_usu_inicial := fug_obt_par_usuario(v_cod_usuario,'COD_USU_PIVOT');
        v_segundo := fue_obt_sig_secuencia(usu.nom_secuencia);
        v_segundo := nvl(v_segundo,0)+1;
        --Actualiza ultimo usuario y nro secuencia de ultimo cambio en tabla de control--
        update ge_con_par_usuarios x
           set x.cod_usu_ult_cambio = null,
               x.nro_ult_cam_secuencia = 0,
               x.tot_acu_uti_secuencia = v_segundo,
               x.cod_usu_actual = v_cod_usu_inicial,
               x.can_usu_utilizados = 1
         where x.cod_usu_pivot = v_cod_usuario;
    end loop;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en PRG_INI_SEC_USUARIOS-'||v_lugar||'-'||sqlerrm);
END;
/

