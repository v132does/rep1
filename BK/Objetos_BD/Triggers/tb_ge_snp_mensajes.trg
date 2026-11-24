CREATE OR REPLACE TRIGGER IT.TB_GE_SNP_MENSAJES
---Jira DYDMR-2597
 BEFORE INSERT
 ON GE_SNP_MENSAJES
 FOR EACH ROW
DECLARE
  
  v_fecha varchar(6);
  v_fec_conv varchar(10);
  v_cod_msj_sin_formato ge_par_dinamicos.val_parametro%type;
  

   BEGIN
   if inserting AND pae_cnf.G_PROGRAMA = 'GMSNPGEN' AND :new.cod_msj_swift=998 then
     v_fecha:=SUBSTR(:new.msj_swift,(INSTR(:new.msj_swift, '/DEPOSITDATE/',1)+13),6);
      v_fec_conv:= substr(v_fecha, 5,2)||'/'||substr(v_fecha,3,2)||'/'||substr(to_char(sysdate,'YYYY'),1,2)||substr(v_fecha,1,2);
     :new.fec_valor:= to_date(v_fec_conv,'dd/mm/yyyy');
   
   end if;
   
   --Proyecto DEPO FLI--CNFNORMA-429--   
   v_cod_msj_sin_formato := fug_obt_pardinamico('DEP_AUT_MSJ_SFO_OPE');
   if instr(v_cod_msj_sin_formato,'MT'||:new.cod_msj_swift) > 0 then
      if :new.nro_referencia is null then
         :new.nro_referencia := pas_snp.fu_obt_sig_nro_referencia;
      end if; 
   end if;
   
EXCEPTION
   when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,'Error en TB_GE_SNP_TRANSFERENCIAS: '|| sqlerrm);
     end if;
END;
/

