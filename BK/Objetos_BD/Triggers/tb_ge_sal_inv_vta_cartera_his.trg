CREATE OR REPLACE TRIGGER IT."TB_GE_SAL_INV_VTA_CARTERA_HIS"
 BEFORE UPDATE 
 ON "IT"."GE_SAL_INV_VTA_CARTERA_HIS"
 FOR EACH ROW
DECLARE
   v_ins_vinculos_nov VARCHAR2(1) DEFAULT 'N';
   rv_scvno           sb_cta_vinculos_nov%ROWTYPE;   
BEGIN 
   if updating then
     --Si se modifico el campo mot_reingreso, se carga el campo usu_reingreso
     If nvl(:old.OPE_RECAPTADOS, 'x') = 'P' and nvl(:new.OPE_RECAPTADOS, 'x') = 'S' then
       :new.usu_reingreso := user;
     --CNFNORMA-438
        v_ins_vinculos_nov   := 'S';
        rv_scvno.cod_persona := fue_obt_cod_persona(:new.ruc_comprador);
        IF :new.cod_modulo <> 15 THEN
           rv_scvno.nro_cuenta  := :new.nro_cuenta;   
        ELSE
           rv_scvno.nro_cuenta  := pas_cri.lf_obt_nro_cta_ori_vencida(:new.nro_cuenta);
        END IF;   
        rv_scvno.relacion    := 'V';--Venta de Cartera
        IF fus_ver_crc_vinculos(rv_scvno.cod_persona, rv_scvno.relacion, rv_scvno.nro_cuenta) = 'S' THEN
           rv_scvno.evento := 'D';
        ELSE
           IF :new.cod_modulo = 15 THEN
              rv_scvno.nro_cuenta  := :new.nro_cuenta;
              IF fus_ver_crc_vinculos(rv_scvno.cod_persona, rv_scvno.relacion, rv_scvno.nro_cuenta) = 'S' THEN
                 rv_scvno.evento := 'D';
              ELSE
                 rv_scvno.evento := NULL;
              END IF;     
           ELSE
              rv_scvno.evento := NULL;            
           END IF;   
        END IF;
        IF nvl(v_ins_vinculos_nov, 'N') = 'S' AND rv_scvno.evento IS NOT NULL THEN
           rv_scvno.fecha       := to_date(to_char(SYSDATE, 'DDMMYYYY') ||
                                           pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS')),
                                           'DDMMYYYY HH24:MI:SS');
           rv_scvno.hora        := pag_gen.fu_obt_sig_segundo(to_char(SYSDATE, 'HH24:MI:SS'));        
           rv_scvno.cod_modulo  := :new.cod_modulo;
           BEGIN
              INSERT INTO sb_cta_vinculos_nov
                 (fecha, hora, nro_cuenta, cod_persona, evento, relacion, cod_modulo)
              VALUES
                 (rv_scvno.fecha, rv_scvno.hora, rv_scvno.nro_cuenta, rv_scvno.cod_persona,
                  rv_scvno.evento, rv_scvno.relacion, rv_scvno.cod_modulo);
           EXCEPTION
              WHEN dup_val_on_index THEN
                 NULL;
           END;
        END IF;
        --
     end if;  
   end if;
END;
/

