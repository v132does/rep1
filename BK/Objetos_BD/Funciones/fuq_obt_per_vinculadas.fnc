CREATE OR REPLACE FUNCTION IT.FUQ_OBT_PER_VINCULADAS(P_NRO_CONTRATO IN CS_CONTRATOS.NRO_CONTRATO%TYPE)
RETURN VARCHAR2 IS 
V_VINCULOS  VARCHAR2(2000) := null;
CURSOR DATOS IS
       select p.nom_completo NOMBRE
          from CS_CON_PERSONAS t, ba_personas p
          where t.nro_contrato = P_NRO_CONTRATO
          and   t.cod_persona = p.cod_persona
          and   p.tipo = 'F';
          
BEGIN
    FOR I IN DATOS LOOP
        IF V_VINCULOS IS NULL THEN
           V_VINCULOS := I.NOMBRE;
        ELSE
           V_VINCULOS := V_VINCULOS ||' - '||I.NOMBRE;
        END IF;
    END LOOP;
    return V_VINCULOS;
EXCEPTION
    when no_data_found Then
         V_VINCULOS := null;
         return V_VINCULOS;
    WHEN OTHERS THEN
         raise_application_error(-20000,'Error al buscar personas vinculadas : '||sqlerrm);

END;
/

