CREATE OR REPLACE PROCEDURE IT.PRB_GEN_RUB_PADRES (p_cod_rubro in varchar2 default null) is
  WW_CDCTPAD   varchar2(15);
  WW_LENHASTA  varchar2(10) := '0102050810';
  ww_cdcuent   varchar2(15);
  ww_padre     varchar2(15);
  ww_htapad    number(2);
  ww_nivel     number(2);
  ww_conteo    number(7);
  ww_dccuent   varchar2(50);
  ww_cdmoned   varchar2(03);
  global_cuenta varchar2(20);
  cursor rubros is
       select *
         from cb_rubros a
        where imputable = 'S'
          and cod_rubro = nvl(p_cod_rubro,cod_rubro)
          and not exists (select 0 from cb_rubros b
                           where b.cod_rubro = a.cod_rub_padre);
BEGIN

  for CB_rubros in rubros loop
    ww_cdcuent:= CB_RUBROS.COD_RUBRO;
    ww_cdctpad:= CB_RUBROS.COD_RUB_PADRE;
    WW_NIVEL     := CB_RUBROS.NIVEL;
    WW_LENHASTA  := '0102050810';
    if to_number(substr(CB_RUBROS.COD_RUBRO,9,2)) = 0 then
       ww_lenhasta := substr(ww_lenhasta,1,8)||substr(ww_lenhasta,11,6);
       ww_nivel := ww_nivel -1;
    end if;
    IF SUBSTR(CB_RUBROS.COD_RUBRO,6,3) = '000' THEN
       WW_LENHASTA := SUBSTR(WW_LENHASTA,1,6)||SUBSTR(WW_LENHASTA,9,8 );
       WW_NIVEL := WW_NIVEL -1;
    END IF;
    IF SUBSTR(CB_RUBROS.COD_RUBRO,4,2) = '00' THEN
       ww_lenhasta := substr(ww_lenhasta,1,4)||substr(ww_lenhasta,7,10);
       ww_nivel := ww_nivel -1;
    END IF;
    LOOP
      IF WW_NIVEL > 2 THEN
         WW_HTAPAD:= TO_NUMBER(SUBSTR(WW_LENHASTA,(WW_NIVEL-1)*2-3,2));
         WW_PADRE := RPAD(SUBSTR(WW_CDCTPAD,1,WW_HTAPAD),15,'0');
      ELSE
         WW_PADRE := null;
      END IF;
      IF NVL(WW_CDCTPAD,' ') <> NVL(WW_CDCUENT,' ') THEN
         SELECT COUNT(*) INTO WW_CONTEO
           FROM CB_RUBROS
          WHERE COD_RUBRO = WW_CDCTPAD;
         IF nvl(WW_CONTEO,0) = 0 THEN
           BEGIN
             SELECT NVL(SUBSTR(DESCRIPCION,1,50),'SIN DESCRIPCION')
               INTO WW_DCCUENT
               FROM CB_RUB_BCP
              WHERE COD_RUB_BCP = SUBSTR(WW_CDCTPAD,1,8)||
                                 SUBSTR(WW_CDCTPAD,3,1)||
                                 SUBSTR(WW_CDCTPAD,9,2);
           EXCEPTION
              WHEN OTHERS THEN WW_DCCUENT := 'SIN DESCRIPCION';
           END;
           WW_CDMONED := 'GS';
           IF SUBSTR(WW_CDCTPAD,14,2) NOT IN ('00','99','98') THEN
              BEGIN
                SELECT COD_MONEDA INTO WW_CDMONED
                  FROM BA_MONEDAS
                 WHERE COD_NUMERICO = TO_NUMBER(SUBSTR(WW_CDCTPAD,14,2));
              EXCEPTION
                 WHEN OTHERS THEN
                    WW_CDMONED := CB_RUBROS.COD_MONEDA;
              END;
           END IF;
           GLOBAL_CUENTA := WW_CDCTPAD;
           --CALCULA_DIGITO_VERIFICADOR;
          if WW_CDCTPAD is not null then
           INSERT INTO CB_RUBROS
             (COD_RUBRO,COD_MONEDA,COD_RUB_PADRE,DESCRIPCION,
              ABREVIATURA,IMPUTABLE,NIVEL,TIPO,NATURALEZA)
           VALUES
             (WW_CDCTPAD,WW_CDMONED,WW_PADRE ,WW_DCCUENT,
              SUBSTR(WW_DCCUENT,1,15),'N',WW_NIVEL-1,CB_RUBROS.TIPO,CB_RUBROS.NATURALEZA);
          end if;

         ELSE
           WW_NIVEL := 2;
         END IF;
      END IF;
      EXIT WHEN WW_NIVEL = 2;
      WW_CDCUENT := WW_CDCTPAD;
      WW_CDCTPAD := WW_PADRE;
      WW_NIVEL   := WW_NIVEL - 1;
   END LOOP;
  end loop;
  --
/*  INSERT INTO CB_RUB_OFICINAS
      (COD_OFICINA,COD_RUBRO, ULT_NRO_EXTRACTO)
  SELECT BA_OFICINAS.COD_OFICINA,CB_RUBROS.COD_RUBRO, ULT_NRO_MAYOR
    FROM BA_OFICINAS, CB_RUBROS
   WHERE BA_OFICINAS.ESTADO = 'A';*/
  ------------------------------------------------------------------
END;
/

