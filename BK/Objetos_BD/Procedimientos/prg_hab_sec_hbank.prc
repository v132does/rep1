CREATE OR REPLACE PROCEDURE IT.PRG_HAB_SEC_HBANK
 IS
   --Habilita uso secuencia para hora HBANK----
   --PCCDEEVO-1045 / Mejora PK usuario HBANK--
   v_lugar  varchar2(50);
   v_ind_uti_sec_hbank varchar2(1);

BEGIN
  v_ind_uti_sec_hbank := fug_obt_pardinamico('IND_UTI_SEC_HBANK');
  if nvl(v_ind_uti_sec_hbank,'N') = 'N' then
    --Habilita secuencia--
    v_lugar := 'Habilita Secuencia';
    prg_act_par_dinamico('IND_UTI_SEC_HBANK',null,null,null,null,'S',null);
    PRG_ENV_MAI_ALE_ATM('AVISO USUARIO HBANK: Habilita modo Secuencia. Cambio de parametro IND_UTI_SEC_HBANK de N a S',
                           USER, trunc(sysdate));
  end if;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en pra_ini_sec_hbank-'||v_lugar||'-'||sqlerrm);
END;
/

