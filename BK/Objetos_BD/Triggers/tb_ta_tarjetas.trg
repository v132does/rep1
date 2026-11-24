CREATE OR REPLACE TRIGGER IT.TB_TA_TARJETAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON IT.TA_TARJETAS
 FOR EACH ROW
DECLARE
   v_pla_ope_por_contado    ta_cta_tarjetas_nov.pla_ope_por_contado%type;
   v_pla_ope_mto_contado    ta_cta_tarjetas_nov.pla_ope_mto_contado%type;
   v_pla_ope_mto_adelanto   ta_cta_tarjetas_nov.pla_ope_mto_adelanto%type;
   v_pla_ope_por_adelanto   ta_cta_tarjetas_nov.pla_ope_por_adelanto%type;
BEGIN
   IF updating THEN
      IF fug_obt_pardinamico('ENV_MOD_TARJETA') = 'S' AND fut_obt_procesadora(:new.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL') THEN
         IF nvl(pae_cnf.g_programa    , 'X') NOT IN ('GPPROFIN', 'GPPROIND') THEN
            null;
            IF nvl(:old.pla_ope_por_contado , 0) <> nvl(:new.pla_ope_por_contado , 0) OR
               nvl(:old.pla_ope_mto_contado , 0) <> nvl(:new.pla_ope_mto_contado , 0) OR
               nvl(:old.pla_ope_mto_adelanto, 0) <> nvl(:new.pla_ope_mto_adelanto, 0) OR
               nvl(:old.pla_ope_por_adelanto, 0) <> nvl(:new.pla_ope_por_adelanto, 0) THEN
               
               IF nvl(:old.pla_ope_por_contado, 0)    <> nvl(:new.pla_ope_por_contado, 0)   THEN
                  v_pla_ope_por_contado := :new.pla_ope_por_contado;
               END IF;
               
               IF nvl(:old.pla_ope_mto_contado, 0)    <> nvl(:new.pla_ope_mto_contado, 0)   THEN
                  v_pla_ope_mto_contado := :new.pla_ope_mto_contado;
               END IF;
               
               IF nvl(:old.pla_ope_mto_adelanto, 0) <> nvl(:new.pla_ope_mto_adelanto, 0)    THEN
                  v_pla_ope_mto_adelanto := :new.pla_ope_mto_adelanto;
               END IF;

               IF nvl(:old.pla_ope_por_adelanto, 0) <> nvl(:new.pla_ope_por_adelanto, 0)    THEN
                  v_pla_ope_por_adelanto := :new.pla_ope_por_adelanto;
               END IF;

               BEGIN
                    update ta_tarjetas_nov
                       set pla_ope_por_contado   = v_pla_ope_por_contado ,
                           pla_ope_mto_contado   = v_pla_ope_mto_contado ,
                           pla_ope_mto_adelanto  = v_pla_ope_mto_adelanto,
                           pla_ope_por_adelanto  = v_pla_ope_por_adelanto
                     where nro_cuenta  = :new.nro_cuenta
                       and nro_tarjeta = :new.nro_tarjeta
                       and fecha       = pag_cal.fu_obt_fec_actual(5);

                    IF SQL%NOTFOUND THEN
                       BEGIN
                          INSERT INTO ta_tarjetas_nov (nro_cuenta          ,
                                                       fecha               ,
                                                       nro_tarjeta         ,
                                                       pla_ope_por_contado ,
                                                       pla_ope_mto_contado ,
                                                       pla_ope_mto_adelanto,
                                                       pla_ope_por_adelanto)

                                                VALUES(:new.nro_cuenta       ,
                                                       pag_cal.fu_obt_fec_actual(5),
                                                       :new.nro_tarjeta      ,
                                                       v_pla_ope_por_contado ,
                                                       v_pla_ope_mto_contado ,
                                                       v_pla_ope_mto_adelanto,
                                                       v_pla_ope_por_adelanto);
                       EXCEPTION
                          WHEN OTHERS THEN
                             IF SQLCODE <= -20000 THEN
                                RAISE;
                             ELSE
                                raise_application_error(-20550,'No se pudo insertar las novedades de tarjetas ' ||SQLERRM);
                             END IF;
                       END;
                    END IF;
               EXCEPTION
                    WHEN OTHERS THEN
                       IF SQLCODE <= -20000 THEN
                          RAISE;
                       ELSE
                          raise_application_error(-20551,'No se pudo actualizar las novedades de tarjetas ' ||SQLERRM);
                       END IF;
               END;
            END IF;
         END IF;
      END IF;
   END IF;
   IF INSERTING THEN 
       IF :new.id is null then
         :new.id := it.fut_obt_cod_uuid;
       END IF;
   END IF;
END;
/
