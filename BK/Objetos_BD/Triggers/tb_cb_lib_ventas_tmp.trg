CREATE OR REPLACE TRIGGER IT.tb_cb_lib_ventas_tmp
   BEFORE INSERT OR UPDATE ON cb_lib_ventas_tmp
   FOR EACH ROW
DECLARE
   v_existe           VARCHAR2(1);
   vmto_exento_gs     cb_lib_ventas.mto_exento_gs%TYPE;
   vmto_gravado_5_gs  cb_lib_ventas.mto_gravado_5_gs%TYPE;
   vmto_gravado_10_gs cb_lib_ventas.mto_gravado_10_gs%TYPE;
BEGIN

   /*Al insertar*/
   IF inserting OR updating THEN
   
      IF :new.reversado = 'S' THEN
      
         --Validar que exista en cb_lib_ventas
         BEGIN
            SELECT '1'
              INTO v_existe
              FROM cb_lib_ventas a
             WHERE a.nro_factura = :new.nro_fac_referencia
               AND a.nro_timbrado = :new.nro_tim_referencia
               AND a.cod_persona = :new.cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Padre no encontrado (cb_lib_ventas), Fact.' ||
                                        :new.nro_fac_referencia || ' Tim.' ||
                                        :new.nro_tim_referencia || ' Pers.' || :new.cod_persona);
            WHEN OTHERS THEN
               raise_application_error(-20000, SQLERRM);
            
         END;
      
         --Validar montos para nota de credito       
         SELECT nvl(a.mto_exento_gs, 0), nvl(a.mto_gravado_5_gs, 0), nvl(a.mto_gravado_10_gs, 0)
           INTO vmto_exento_gs, vmto_gravado_5_gs, vmto_gravado_10_gs
           FROM cb_lib_ventas a
          WHERE a.nro_factura = :new.nro_fac_referencia
            AND a.nro_timbrado = :new.nro_tim_referencia;
      
         IF nvl(:new.mto_exento, 0) > vmto_exento_gs THEN
            raise_application_error(-20000,
                                    'Valor de Monto Exento para Nota de Crédito no debe superar el monto de la factura original. ' ||
                                     vmto_exento_gs);
         END IF;
      
         IF nvl(:new.mto_gravado_5, 0) > vmto_gravado_5_gs THEN
            raise_application_error(-20000,
                                    'Valor de Monto Gravado 5% para Nota de Crédito no debe superar el monto de la factura original. ' ||
                                     vmto_gravado_5_gs);
         END IF;
      
         IF nvl(:new.mto_gravado_10, 0) > vmto_gravado_10_gs THEN
            raise_application_error(-20000,
                                    'Valor de Monto Gravado 10% para Nota de Crédito no debe superar el monto de la factura original. ' ||
                                     vmto_gravado_10_gs);
         END IF;
      END IF;
   
   END IF;

END;
/

