CREATE OR REPLACE PROCEDURE IT.PRG_HAB_SEC_ATM
 IS
   --Habilita uso secuencia para hora ATM--
   v_lugar  varchar2(50);
   v_ind_uti_sec_atm varchar2(1);
   
BEGIN
  v_ind_uti_sec_atm := fug_obt_pardinamico('IND_UTI_SEC_ATM');
  if nvl(v_ind_uti_sec_atm,'N') = 'N' then
    --Habilita secuencia--
    v_lugar := 'Habilita Secuencia';
    prg_act_par_dinamico('IND_UTI_SEC_ATM',null,null,null,null,'S',null);
    PRG_ENV_MAI_ALE_ATM('AVISO USUARIO ATM: Habilita modo Secuencia. Cambio de parametro IND_UTI_SEC_ATM de N a S',
                           USER, trunc(sysdate));  
  end if;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en pra_ini_sec_atm-'||v_lugar||'-'||sqlerrm);
END;
/

