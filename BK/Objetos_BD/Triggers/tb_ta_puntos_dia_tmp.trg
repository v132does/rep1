CREATE OR REPLACE TRIGGER IT.tb_ta_puntos_dia_tmp
  before insert on ta_puntos_dia_tmp  
  for each row
DECLARE
   -- local variables here
BEGIN
   /*
   || Campo             Long   Observación
   || ====================================
   || Código de Banco   2,0    
   || Clase Tarjeta     2,0    
   || Afinidad          2      
   || Cuenta            9,0    
   || Fecha Movimiento  8     aaaammdd
   || Tipo Mov.         1      S= generado por sistema, E= Especial, B= Baja, C= Canje, V= Vencido
   || Puntos            9,0    
   */
   BEGIN
      :new.cod_banco := TRIM(substr(:new.fila, 1, 2));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.cla_tarjeta := TRIM(substr(:new.fila, 3, 2));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   :new.afinidad := TRIM(substr(:new.fila, 5, 2));
   ---
   BEGIN
      :new.cuenta := TRIM(substr(:new.fila, 7, 9));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   :new.fec_movimiento := TRIM(substr(:new.fila, 16, 8));
   :new.tip_movimiento := TRIM(substr(:new.fila, 24, 1));
   ---
   BEGIN
      :new.puntos := TRIM(substr(:new.fila, 25, 9));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
END ta_ta_extracto_det_tmp;
/

