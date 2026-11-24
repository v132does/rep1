CREATE OR REPLACE PROCEDURE IT.PRG_INS_TAS_RANGOS
IS
-- Variables.
v_cod_tasa     ge_tas_interpolada.cod_tasa%type;
v_fec_vigencia ge_tas_interpolada.fec_vigencia%type;
v_fec_actual   ge_tas_interpolada.fec_vigencia%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_existe       number := 0;
--SDMODFTP-1 - Nov/2019

BEGIN
   
   -- Verifica que exista registros a insertar.
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada;
    
   IF v_existe = 0 THEN
      raise_application_error(-20000, 'No existen datos en la tabla ge_tas_interpolada.');
   END IF;
   
   -- Valida que la Fecha de Vigencia contenga datos.
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada a
    WHERE a.fec_vigencia IS NULL;
    
   IF v_existe > 0 THEN
      raise_application_error(-20000, 'No se puede ingresar valores NULOS en el campo FEC_VIGENCIA.');
   END IF;
   
   -- Se debe importar solamente las Tasas que se encuentren parametrizadas en la Referencia General IMP_COD_TAS_RANGOS.
   SELECT MIN(a.cod_tasa) 
     INTO v_cod_tasa
     FROM ge_tas_interpolada a 
    WHERE NOT EXISTS (SELECT 1 FROM ba_cod_referencias m WHERE m.dominio = 'IMP_COD_TAS_RANGOS' and m.val_minimo = a.cod_tasa);
   
   IF v_cod_tasa IS NOT NULL THEN
      raise_application_error(-20000, 'El Código de Tasa: '||v_cod_tasa||', no esta habilitado para la Importación de Datos. Verificar la Referencia General IMP_COD_TAS_RANGOS.');
   END IF;
   
   -- Valida que no se ingrese importes negativos.
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada a
    WHERE a.val_hasta < 0;
    
   IF v_existe > 0 THEN
      raise_application_error(-20000, 'No se puede ingresar valores negativos en el campo VAL_HASTA.');
   END IF;
     
   -- Valida que no se ingrese porcentajes negativos, ni superiores al 100%.
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada a
    WHERE a.val_tasa < 0;
    
   IF v_existe > 0 THEN
      raise_application_error(-20000, 'No se puede ingresar valores negativos en el campo VAL_TASA.');
   END IF;
   --
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada a
    WHERE a.val_tasa > 100;
    
   IF v_existe > 0 THEN
      raise_application_error(-20000, 'No se puede ingresar porcentaje superiores al 100% en el campo VAL_TASA.');
   END IF;
   
   -- Valida que no se ingrese porcentajes negativos, ni superiores al 100% en el campo VAL_EXTENSION.
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada a
    WHERE a.val_extension < 0;
    
   IF v_existe > 0 THEN
      raise_application_error(-20000, 'No se puede ingresar valores negativos en el campo VAL_EXTENSION.');
   END IF;
   --
   SELECT count(1) 
     INTO v_existe
     FROM ge_tas_interpolada a
    WHERE a.val_extension > 100;
    
   IF v_existe > 0 THEN
      raise_application_error(-20000, 'No se puede ingresar porcentaje superiores al 100% en el campo VAL_EXTENSION.');
   END IF;
      
   -- Obtiene la Fecha de Vigencia de la Tasa registrada actualmente.
   FOR reg IN (SELECT distinct a.cod_tasa, a.fec_vigencia FROM ge_tas_interpolada a) LOOP
      -- Obtengo la Fecha de Vigencia.
      BEGIN
         SELECT NVL(MAX(a.fec_vigencia),v_fec_actual)
           INTO v_fec_vigencia
           FROM ge_tas_rangos a
          where a.cod_tasa = reg.cod_tasa;
         
         IF reg.fec_vigencia <= v_fec_vigencia THEN
            raise_application_error(-20000, 'La fecha de vigencia de la tasa '||reg.cod_tasa||' no debe ser menor a la fecha de vigencia actual. Fecha de Vigencia Actual: '||to_char(v_fec_vigencia,'dd/mm/yyyy'));
         END IF;      
      END;
   END LOOP;

   -- Inserto los registros en la tabla ge_tas_rangos.
   INSERT INTO ge_tas_rangos(cod_tasa, 
                             fec_vigencia, 
                             cod_oficina, 
                             cod_moneda, 
                             cod_modulo, 
                             cod_modalidad, 
                             nro_cuenta, 
                             val_hasta, 
                             val_tasa, 
                             cod_sub_modalidad, 
                             no_actualizable, 
                             val_extension, 
                             cod_persona, 
                             observaciones, 
                             fec_vencimiento, 
                             cod_ente)
        SELECT cod_tasa, fec_vigencia, cod_oficina, cod_moneda, cod_modulo, cod_modalidad, nro_cuenta, val_hasta, val_tasa, 
               cod_sub_modalidad, no_actualizable, val_extension, cod_persona, observaciones, fec_vencimiento, cod_ente
          FROM ge_tas_interpolada;
   
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'PRG_INS_TAS_RANGOS: '|| sqlerrm);
END;
/

