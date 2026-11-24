CREATE OR REPLACE TRIGGER IT.tb_ta_extracto_det_tmp
  before insert on ta_extracto_det_tmp  
  for each row
DECLARE
   -- local variables here
BEGIN
   /*
   || Inicio Fin Long. Dec. Tipo Nombre Descripcion
   || =============================================
   || 1      2   2     00   S    CODBCO   Código Banco
   || 3      4   2     00   S    CODCLA   Clase Tarjeta
   || 5      6   2     00   S    CODAFI   Código Afinidad
   || 7      15  9     00   S    NROCTA   Cuenta
   || 16     18  3     00   S    NROSEC   Nro. de Secuencia
   || 19     37  19         A    TAR19A   Tarjeta
   || 38     45  8     00   S    FECOMP   Fecha Compra(AAAAMMDD)
   || 46     53  8     00   S    FECPRO   Fecha Proceso(AAAAMMDD)
   || 54     60  7     00   S    CODCOM   Código de Comercio
   || 61     61  1          A    CAJA     Caja(*1)
   || 62     64  3     00   S    NCARAT   Nro. de Caratula
   || 65     73  9     00   S    NRRESU   Nro. Resumen
   || 74     80  7     00   S    CUPON    Nro. Cupón
   || 81     82  2     00   S    ORICUP   Origen del Cupón (Cero)
   || 83     93  11    02   S    MONTO$   Monto
   || 94     117 24         A    DESADI   Descrip. Adicional (*2)
   || 118    118 1          A    TIREGI   Tipo de Registro
   || 119    119 1          A    TIPTRA   Tipo Transacción (*3)
   || 120    121 2     00   S    LONTAR   Longitud de la Tarjeta
   || 122    129 8     00   S    FECCIE   Fecha Cierre (AAAAMMDD)
   || 130    130 1          A    TIPCIE   Tipo Cierre
   || 131    132 2     00   S    DTGRUP   Agrupación
   || 133    135 3          A    X2COPAIS Cod. Pais(*4)
   || 136    138 3     00   S    X2CODMON Cod. Moneda(*5)
   || 139    144 11    02   P    X2MOTORI Monto Origen (*6)
   || 145    149 9     00   P    X2COMISI Comisión
   || 150    154 9     00  P    X2IVA    Iva
   || 155    157 4     00  P    X2MCC    MCC
   || 158    159 2     00  P    X2AFESAL Afectación
   || 160    164 9     02  P    X2PUNCBR Puntaje Cobranding 
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
   BEGIN
      :new.nro_secuencia := TRIM(substr(:new.fila, 16, 3));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   :new.nro_tarjeta := TRIM(substr(:new.fila, 19, 19));
   ---
   BEGIN
      :new.fec_compra := to_date(substr(:new.fila, 38, 8), 'yyyymmdd');
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   BEGIN
      :new.fec_proceso := to_date(substr(:new.fila, 46, 8), 'yyyymmdd');
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   BEGIN
      :new.cod_comercio := TRIM(substr(:new.fila, 54, 7));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   :new.tip_caja := TRIM(substr(:new.fila, 61, 1));
   ---
   BEGIN
      :new.nro_caratula := TRIM(substr(:new.fila, 62, 3));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.nro_resumen := TRIM(substr(:new.fila, 65, 9));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.nro_cupon := TRIM(substr(:new.fila, 74, 7));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.ori_cupon := TRIM(substr(:new.fila, 81, 2));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.monto := TRIM(substr(:new.fila, 83, 11));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   :new.des_adicional   := TRIM(substr(:new.fila, 94, 24));
   :new.tip_registro    := TRIM(substr(:new.fila, 118, 1));
   :new.tip_transaccion := TRIM(substr(:new.fila, 119, 1));
   ---
   BEGIN
      :new.lon_tarjeta := TRIM(substr(:new.fila, 120, 2));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   BEGIN
      :new.fec_cierre := to_date(substr(:new.fila, 122, 8), 'yyyymmdd');
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   ---
   :new.tip_cierre := TRIM(substr(:new.fila, 130, 1));
   BEGIN
      :new.agrupacion := TRIM(substr(:new.fila, 131, 2));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   :new.cod_pais   := TRIM(substr(:new.fila, 133, 3));
   :new.cod_moneda := TRIM(substr(:new.fila, 136, 3));
   ---
   BEGIN
      :new.mto_origen := TRIM(substr(:new.fila, 139, 11));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.comision := TRIM(substr(:new.fila, 150, 9));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.iva := TRIM(substr(:new.fila, 159, 9));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.mcc := TRIM(substr(:new.fila, 168, 4));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.afectacion := TRIM(substr(:new.fila, 172, 2));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   BEGIN
      :new.pun_cobrading := TRIM(substr(:new.fila, 174, 9));
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

END ta_ta_extracto_det_tmp;
/

