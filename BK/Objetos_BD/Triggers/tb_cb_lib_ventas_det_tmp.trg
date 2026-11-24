CREATE OR REPLACE TRIGGER IT.tb_cb_lib_ventas_det_tmp
   BEFORE INSERT OR UPDATE ON cb_lib_ventas_det_tmp
   FOR EACH ROW

BEGIN

   /*Al insertar o actualizar*/
   IF inserting OR updating THEN
   
      --Validar que no se carguen registros de exento con gravado
      IF nvl(:new.mto_exento_gs, 0) > 0 AND
         (nvl(:new.mto_gra_5_gs, 0) > 0 OR nvl(:new.mto_gra_10_gs, 0) > 0) THEN
         raise_application_error(-20000,
                                 'Monto Exento Gs. y Monto Gravado Gs. no deben ir en el mismo registro.');
      END IF;
   
      IF nvl(:new.mto_exento, 0) > 0 AND
         (nvl(:new.mto_gravado_5, 0) > 0 OR nvl(:new.mto_gravado_10, 0) > 0) THEN
         raise_application_error(-20000,
                                 'Monto Exento y Monto Gravado no deben ir en el mismo registro.');
      END IF;
   
   END IF;

END tb_cb_lib_ventas_det;
/

