CREATE OR REPLACE PROCEDURE IT.pro_act_cli_telefonos IS
  CURSOR c_tel_rec IS
  SELECT DISTINCT * FROM co_telefonos_tmp a
   WHERE a.valido = '1'
     AND NOT EXISTS (SELECT 1 FROM ba_telefonos b
                       WHERE b.cod_persona = a.cod_cliente
                         AND b.tipo        = decode(a.tip_telefono,'L','W','I')
                         AND b.area        = a.cod_area
                         AND b.telefono    = a.numero);
BEGIN
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End; 
  FOR k IN c_tel_rec LOOP
    --
    BEGIN
      UPDATE ba_telefonos a
         SET tipo = decode(k.tip_telefono,'L','W','I')
       WHERE a.cod_persona = k.cod_cliente
         AND a.tipo        = k.tip_telefono
         AND a.area        = k.cod_area
         AND a.telefono    = k.numero;

      IF SQL%ROWCOUNT < 1 THEN
        INSERT INTO ba_telefonos
          (cod_persona, 
           cod_telefono, 
           telefono, 
           tipo, 
           area, 
           interno, 
           tip_linea, 
           principal)
         VALUES
          (k.cod_cliente, 
           null,
           to_number(trim(k.numero)), 
           decode(k.tip_telefono,'L','W','I'),
           k.cod_area,
           null,
           'B',
           'N'
          );
      END IF;
    END;
  END LOOP;
END;
/

