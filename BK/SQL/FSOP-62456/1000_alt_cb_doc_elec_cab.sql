ALTER TABLE IT.cb_doc_elec_cab ADD (cOblAfe     NUMBER(3),
                                    dDesoblAfe  VARCHAR2(65));
                                    
COMMENT ON COLUMN IT.cb_doc_elec_cab.cOblAfe
     IS 'Tipo de obligaciones';
     
COMMENT ON COLUMN IT.cb_doc_elec_cab.dDesoblAfe
     IS 'Descripción de la obligación afectada';