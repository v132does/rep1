CREATE OR REPLACE PROCEDURE IT.pro_act_cli_direcciones IS
  CURSOR c_direc IS
  SELECT distinct * FROM co_domicilios_tmp a
   WHERE a.valido = '1'
     AND NOT EXISTS (SELECT 1 FROM ba_direcciones b
                      WHERE b.cod_persona = a.cod_cliente
                        AND b.tipo = decode(a.tip_domicilio,'L','W','I')
                        AND b.direccion = a.calle);
BEGIN
  BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END; 
  FOR k IN c_direc LOOP
    BEGIN
      UPDATE ba_direcciones a
         SET a.tipo = decode(k.tip_domicilio,'L','W','I')
       WHERE a.cod_persona = k.cod_cliente
         AND a.tipo = k.tip_domicilio
         AND a.direccion = k.calle;

      IF SQL%ROWCOUNT < 1 THEN
        INSERT INTO ba_direcciones
        (cod_persona,
         cod_direccion,
         tipo,
         principal,
         direccion,
         cod_pais,
         cod_ciudad,
         cod_barrio,
         observacion,
         numero,
         departamento,
         piso,
         edificio,
         cod_postal)
         VALUES
        (k.cod_cliente,
         k.cod_domicilio,
         decode(k.tip_domicilio,'L','W','I'),
         'N',
         k.calle,
         1,
         k.localidad,
         null,
         'Dirección de Archivo Recovery Stretagy.',
         k.nro_casa,
         k.departamento,
         k.piso,
         null,
         k.cod_postal);
      END IF;
    END;
  END LOOP;
END;
/

