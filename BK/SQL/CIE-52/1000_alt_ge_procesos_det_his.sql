ALTER TABLE it.ge_procesos_det_his
ADD (
  usu_insercion    VARCHAR2(10) DEFAULT SUBSTR(USER, 1, 10) NOT NULL,
  fec_insercion    DATE DEFAULT SYSDATE NOT NULL,
  usu_modificacion VARCHAR2(10) DEFAULT SUBSTR(USER, 1, 10) NOT NULL,
  fec_modificacion DATE DEFAULT SYSDATE NOT NULL
);
