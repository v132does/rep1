DECLARE
   v_valor_deseado NUMBER := 16505;
   v_valor_actual  NUMBER;
   v_diferencia    NUMBER;
BEGIN

   SELECT it.S_NRO_GARANTIA.NEXTVAL INTO v_valor_actual FROM DUAL;


   v_diferencia := v_valor_deseado - v_valor_actual - 1;

   IF v_diferencia <> 0 THEN

      EXECUTE IMMEDIATE 'ALTER SEQUENCE it.S_NRO_GARANTIA INCREMENT BY ' || v_diferencia;


      SELECT it.S_NRO_GARANTIA.NEXTVAL INTO v_valor_actual FROM DUAL;
   END IF;


   EXECUTE IMMEDIATE 'ALTER SEQUENCE it.S_NRO_GARANTIA INCREMENT BY 1';
END;
/
