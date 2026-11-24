CREATE OR REPLACE TRIGGER IT.TA_CJ_MOVIMIENTOS
 AFTER DELETE OR INSERT OR UPDATE
 ON "IT"."CJ_MOVIMIENTOS"
 FOR EACH ROW
DECLARE
  v_nro_documento    number(7);
  v_nro_referencia   cj_mov_prodep.nro_referencia%type;
  v_fecha            date := pag_cal.fu_obt_fec_actual(9);
BEGIN
  IF inserting THEN
     IF :new.tip_monto in ('O', 'T', 'S') AND
        :new.monto > 0 AND
        :new.tipo = 'D' THEN
        IF :new.nro_documento IS NULL THEN
           BEGIN
             SELECT s_nro_ref_prodep.nextval
               INTO v_nro_documento
               FROM dual;
           EXCEPTION
             WHEN OTHERS THEN
               v_nro_documento := 0;
           END;
       ELSE
         v_nro_documento := substr(:new.nro_documento, 1, 7);
       END IF;
       v_nro_referencia := to_char(v_fecha, 'ddmmyyyy')||lpad(v_nro_documento, 7, '0');
       BEGIN
         INSERT INTO cj_mov_prodep(nro_referencia, fecha, hora, cod_usuario,
                                   nro_secuencia, cod_tra_padre, cod_mod_padre, cod_mad_padre,
                                   cod_oficina, cod_moneda, nro_caja, nro_cuenta,
                                   monto, estado, nro_documento, tip_monto)
                            VALUES(v_nro_referencia, :new.fecha, :new.hora, :new.cod_usuario,
                                   :new.nro_secuencia, :new.cod_tra_padre, :new.cod_mod_padre, :new.cod_mad_padre,
                                   :new.cod_oficina, :new.cod_moneda, :new.nro_caja, :new.nro_cuenta,
                                   :new.monto, :new.estado, :new.nro_documento, :new.tip_monto);
       END;
     END IF;
  ELSIF updating THEN
     IF :new.estado <> :old.estado AND
        :new.tip_monto IN ('O', 'T', 'S') AND
        :new.tipo = 'D' THEN
        UPDATE cj_mov_prodep
           SET estado = :new.estado
         WHERE fecha = :new.fecha
           AND hora = :new.hora
           AND cod_usuario = :new.cod_usuario
           AND nro_secuencia = :new.nro_secuencia;
     END IF;
  ELSIF deleting THEN
     IF :old.tip_monto IN ('O', 'T', 'S') AND :old.tipo = 'D' THEN
        BEGIN
          DELETE cj_mov_prodep
           WHERE fecha = :new.fecha
             AND hora = :new.hora
             AND cod_usuario = :new.cod_usuario
             AND nro_secuencia = :new.nro_secuencia;
        END;
     END IF;
  END IF;
END;
/

