CREATE OR REPLACE PROCEDURE IT.PRG_INI_SEC_ATM
 IS
   -- Reinicializa Secuencia en FIN de DIA--
   v_lugar  varchar2(50);
   v_segundo number;
   v_error varchar2(400);
   v_ind_uti_sec_atm varchar2(1);
BEGIN
    v_ind_uti_sec_atm := fug_obt_pardinamico('IND_UTI_SEC_ATM');
    if nvl(v_ind_uti_sec_atm,'N') = 'S' then
      --Inicializa secuencia--
      v_lugar := 'Inicializa Secuencia';
      select S_SIG_HOR_ATM.Nextval into v_segundo from dual;
      v_segundo := nvl(v_segundo,0)+1;
      --Actualiza ultimo usuario y nro secuencia de ultimo cambio en tabla de control--
      update GE_CON_PAR_ATM t 
         set t.cod_usu_ult_cambio=null,
         t.nro_ult_cam_secuencia=0,
         t.tot_acu_uti_secuencia=v_segundo;
    end if;
EXCEPTION
   WHEN OTHERS THEN  
      raise_application_error(-20000,'Error en pra_ini_sec_atm-'||v_lugar||'-'||sqlerrm);
END;
/

