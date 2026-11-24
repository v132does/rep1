CREATE OR REPLACE PROCEDURE IT.PRG_INI_SEC_HBANK
 IS
   -- Reinicializa Secuencia en FIN de DIA----
   --PCCDEEVO-1045 / Mejora PK usuario HBANK--
   v_lugar  varchar2(50);
   v_segundo number;
   v_error varchar2(400);
   v_ind_uti_sec_HBANK varchar2(1);
BEGIN
    v_ind_uti_sec_HBANK := fug_obt_pardinamico('IND_UTI_SEC_HBANK');
    if nvl(v_ind_uti_sec_HBANK,'N') = 'S' then
      --Inicializa secuencia--
      v_lugar := 'Inicializa Secuencia';
      select S_SIG_HOR_HBANK.Nextval into v_segundo from dual;
      v_segundo := nvl(v_segundo,0)+1;
      --Actualiza ultimo usuario y nro secuencia de ultimo cambio en tabla de control--
      update GE_CON_PAR_HBANK t
         set t.cod_usu_ult_cambio=null,
         t.nro_ult_cam_secuencia=0,
         t.tot_acu_uti_secuencia=v_segundo;
    end if;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en pra_ini_sec_HBANK-'||v_lugar||'-'||sqlerrm);
END;
/

