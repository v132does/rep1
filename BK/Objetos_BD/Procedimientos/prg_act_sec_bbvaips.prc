CREATE OR REPLACE PROCEDURE IT.PRG_ACT_SEC_BBVAIPS
 IS
   --DYDMR-22560 Mejora PK usuario BBVAIPS
   --proceso unificado de activacion y reinicializacion de secuencia diaria del usuario BBVAIPS
   v_lugar  varchar2(50);
   v_ind_uti_sec_bbvaips varchar2(1);
   v_segundo number;

BEGIN
  --Habilita uso secuencia para hora BBVAIPS
  v_ind_uti_sec_BBVAIPS := fug_obt_pardinamico('IND_UTI_SEC_BBVAIPS');
  if nvl(v_ind_uti_sec_BBVAIPS,'N') = 'N' then
    --Habilita secuencia--
    v_lugar := 'Habilita Secuencia';
    prg_act_par_dinamico('IND_UTI_SEC_BBVAIPS',null,null,null,null,'S',null);
    PRG_ENV_MAI_ALE_ATM('AVISO USUARIO BBVAIPS: Habilita modo Secuencia. Cambio de parametro IND_UTI_SEC_BBVAIPS de N a S',
                           USER, trunc(sysdate));
  end if;
  --Inicializa secuencia--
  v_lugar := 'Inicializa Secuencia';
  select S_SIG_HOR_BBVAIPS.Nextval into v_segundo from dual;
  v_segundo := nvl(v_segundo,0)+1;
  --Actualiza ultimo usuario y nro secuencia de ultimo cambio en tabla de control--
  update GE_CON_PAR_BBVAIPS t
     set t.cod_usu_ult_cambio=null,
     t.nro_ult_cam_secuencia=0,
     t.tot_acu_uti_secuencia=v_segundo;

  --Actualiza el parámetro de Cantidad de Movimientos--
  prg_act_par_dinamico('COD_USU_ACT_BBVAIPS',null,null,null,null,'BBVAIPS',null);
  prg_act_par_dinamico('CAN_USU_UTI_BBVAIPS',null,null,null,null,'1',null);
    
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en PRG_ACT_SEC_BBVAIPS-'||v_lugar||'-'||sqlerrm);
END;
/

