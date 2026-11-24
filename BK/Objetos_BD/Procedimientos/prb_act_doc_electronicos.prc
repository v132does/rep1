CREATE OR REPLACE PROCEDURE IT.prb_act_doc_electronicos
 IS
   v_documento     cb_lib_ventas.nro_factura%type;
   v_timbrado      cb_lib_ventas.nro_timbrado%type;
   v_tipo          cb_lib_ventas.tip_comprobante%type;

   CURSOR v_cursor IS
        SELECT e.nro_documento,
               e.nro_timbrado,
               e.tip_comprobante
          FROM CB_DOC_ELECTRONICOS_TMP e;

BEGIN
   -- ACTUALIZACION DE DATOS
   IF v_cursor%ISOPEN THEN
      CLOSE v_cursor;
   END IF;
   OPEN v_cursor;

   LOOP
   FETCH v_cursor
   INTO v_documento, v_timbrado, v_tipo;
        EXIT WHEN v_cursor%NOTFOUND;

        update cb_lib_ventas v
           set v.estado = null
         where v.nro_factura     = v_documento
           and v.nro_timbrado    = v_timbrado
           and v.tip_comprobante = v_tipo;
   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en prb_act_doc_electronicos ' || SQLERRM);
END;
/

