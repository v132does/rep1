create or replace force view it.gv_dir_envios as
Select e.cod_persona,
       substr(decode(e.tip_envio,
              'D', d.direccion ||decode(d.numero,null,'',' '||d.numero)||decode(d.dir_lateral,null,'',' '||d.dir_lateral), -- Direccion y nro --se agrega dir_lateral --> dydmr-4133
              'C', 'CASILLERO: '||e.referencia, -- Casillero
              'A', 'CASILLA DE CORREO: '||e.referencia, -- Casilla de correo
              'R', 'RETENER EN '||o.descripcion), 1, 50)
              dir_envio,
      ---
      decode(e.tip_envio,
                    'R', -- Retener
                    substr(e.observacion, 1, 50),
                    'D', -- Direccion
                    decode(50-length(d.direccion ||decode(d.numero,null,'',' '||d.numero)||decode(d.dir_lateral,null,'',' '||d.dir_lateral)), abs(50-length(d.direccion ||decode(d.numero,null,'',' '||d.numero)||decode(d.dir_lateral,null,'',' '||d.dir_lateral))),
                           substr(d.observacion, 1, 50), -- La longitud de la direccion es menor a 50
                           substr(d.direccion ||decode(d.numero,null,'',' '||d.numero)||decode(d.dir_lateral,null,'',' '||d.dir_lateral), 51, 50))) -- Toma los caracteres restantes
               Prim_Observacion,
      ---
      decode(e.tip_envio,
                    'R', -- Retener
                        decode(50-length(e.observacion), abs(50-length(e.observacion)),
                           null, -- La longitud de la observacion es menor a 50
                           substr(e.observacion, 51, 50)), -- Toma los caracteres restantes
                    'D', -- Direccion
                    decode(50-length(d.observacion), abs(50-length(d.observacion)),
                           null, -- La longitud de la observacion es menor a 50
                           substr(d.observacion, 51, 50))) -- Toma los caracteres restantes
               Seg_Observacion,
      ---
      p.cod_pais cod_pais,
      c.cod_ciudad cod_ciudad,
      b.cod_barrio cod_barrio,
      p.descripcion des_pais,
      c.descripcion des_ciudad,
      b.descripcion des_barrio,
      t.area||decode(t.area, null, null, '-')||t.telefono tel_principal,
      xx_tel_alternativo tel_alternativo,
      e.nro_cuenta,
      e.tip_envio,
      d.cod_direccion,
      o.cod_dir_retencion,
      e.referencia,
      d.piso,d.departamento,d.edificio,
      d.principal
From  ba_barrios b, ba_ciudades c, ba_paises p, ba_telefonos t,
      ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e,
(select x.cod_persona xx_cod_persona,
        x.area||decode(x.area, null, null, '-')||x.telefono xx_tel_alternativo
   from ba_telefonos x
  where x.principal = 'N'
    and x.cod_telefono = (select min(y.cod_telefono)
                            from ba_telefonos y
                           where y.cod_persona = x.cod_persona
                             and y.principal = 'N')
 )
where p.cod_pais(+) = d.cod_pais
  and c.cod_pais(+) = d.cod_pais
  and c.cod_ciudad(+) = d.cod_ciudad
  and b.cod_pais(+) = d.cod_pais
  and b.cod_ciudad(+) = d.cod_ciudad
  and b.cod_barrio(+) = d.cod_barrio
  and t.cod_persona(+) = e.cod_persona
  and t.principal(+) = 'S'
  and d.cod_persona(+) = e.cod_persona
  and d.cod_direccion(+) = e.referencia
  and o.cod_dir_retencion(+) = e.referencia
  and xx_cod_persona(+) = e.cod_persona
  and LENGTH(TRIM(TRANSLATE(e.referencia, '0123456789',' '))) is null /*DYDMR-4616 Ago/2016*/
;

