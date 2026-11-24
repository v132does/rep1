CREATE OR REPLACE TRIGGER IT.TB_CC_LIN_SOB_GARANTIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_LIN_SOB_GARANTIAS
 FOR EACH ROW
declare
 v_ins_gar_eliminadas VARCHAR2(1) DEFAULT 'N';
 rv_scgel        sb_cta_gar_eliminadas%ROWTYPE;

 -- Se agrega cursor para eliminacion de lineas de sobregiros asociadas a mas de una cuenta -- DYDMR-1195 -- CN 27/10/2014
 cursor c_lin_sob( p_nro_secuencia cc_lin_sobregiros.nro_secuencia%type ) is
  select s.cod_persona, s.nro_cuenta
    into rv_scgel.cod_persona, rv_scgel.nro_cuenta
    from cc_lin_sobregiros s
   where s.nro_sec_padre = p_nro_secuencia;

BEGIN
   IF updating THEN
      IF :new.cod_garantia <> :old.cod_garantia THEN
         raise_application_error(-20000,
         'El tipo de garantía no puede modificarse');
      END IF;
   END IF;
   if updating then
      if :old.nro_garantia <> :new.nro_garantia
         or :old.cod_garantia <> :new.cod_garantia
         or :old.mto_aplicado <> :new.mto_aplicado then
         v_ins_gar_eliminadas := 'S';
      end if;
   end if;
   if deleting then
      v_ins_gar_eliminadas := 'S';
   end if;
   if nvl(v_ins_gar_eliminadas, 'N') = 'S' and nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
      -- Se reemplaza por cursor para eliminacion de lineas de sobregiros asociadas a mas de una cuenta -- DYDMR-1195 -- CN 27/10/2014
      if c_lin_sob%isopen then
         close c_lin_sob;
      end if;
      open c_lin_sob(:old.nro_secuencia);
      loop
        fetch c_lin_sob into rv_scgel.cod_persona, rv_scgel.nro_cuenta;
        exit when c_lin_sob%notfound;
        rv_scgel.fecha := to_date(to_char(sysdate,'dd/mm/yyyy')||to_char(sysdate,'hh24:mi:ss') , 'dd/mm/yyyy hh24:mi:ss');
        rv_scgel.hora := to_char(sysdate,'HH24:MI:SS');
        rv_scgel.nro_garantia := nvl(:old.nro_garantia, 0);
        rv_scgel.cod_garantia := :old.cod_garantia;
        rv_scgel.mto_apl_computable := :old.mto_aplicado;
        if rv_scgel.nro_cuenta is not null then
           pas_cri.pr_ins_cta_gar_eliminadas(rv_scgel);
        end if;
      end loop;
      if c_lin_sob%isopen then
         close c_lin_sob;
      end if;
   end if;
END;
/

